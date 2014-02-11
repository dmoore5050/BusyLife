class SynchronizationsController < ApplicationController
  before_filter :authenticate_user!, except: [:trello_listener, :evernote_listener]

  $evernote_listener_counter = 0

  def new
    ev_expiration_check = evernote_client.note_store
    tr_expiration_check = trello_client.boards

    if ev_expiration_check == 'invalid token'
      current_user.authentications.where(provider: 'evernote').first.destroy
      redirect_to authentications_reauthenticate_url provider: 'evernote'
    elsif tr_expiration_check == 'invalid token'
      current_user.authentications.where(provider: 'trello').first.destroy
      redirect_to authentications_reauthenticate_url provider: 'trello'
    end

    NotebookBoard.validate_records
  end

  def prepare
    if params[:notebook_board][:notebook_id].first.blank? && params[:notebook_board][:board_id].blank?
      redirect_to new_synchronization_url, flash: { notebook_validation: "Please select at least one notebook.", board_validation: "Please select a board." }
    elsif params[:notebook_board][:notebook_id].first.blank?
      redirect_to new_synchronization_url, flash: { notebook_validation: "Please select at least one notebook." }
    elsif params[:notebook_board][:board_id].blank?
      redirect_to new_synchronization_url, flash: { board_validation: "Please select a board." }
    else
      notebook_params = params[:notebook_board][:notebook_id].reject(&:blank?)

      notebook_params.each do |notebook|
        the_notebook = Notebook.set_notebook notebook, current_user.id
        notebook_set << the_notebook
        notes_string = evernote_client.build_note_array the_notebook
        nbbs << NotebookBoard.set_notebook_board(board_match, the_notebook, notes_string)
      end

      redirect_to map_synchronizations_path notebook_boards: paramify(nbbs), notebooks: paramify(notebook_set), board: board_match.id
    end
  end

  def map
    @board_match  = Board.find params[:board].to_i
    @notebook_set = unparamify params[:notebooks], Notebook
    @nbbs         = unparamify params[:notebook_boards], NotebookBoard
  end

  def create
    share_flag   = params[:notebook_board][:share_flag]
    synch_params = params[:notebook_board][:list_id]
    list_params  = params[:new_list_params]

    synch_params.each_with_index do |(_, value), i|
      if value.blank?                                                           # create new list
        list_name, board_guid, nbb_id, notebook_guid = list_params["#{i}"].split('|')
        trello_list = trello_client.create_list list_name, board_guid
        list_guid = trello_list.id
      else                                                                      # use existing list
        list_guid, list_name, nbb_id, notebook_guid = value.split('|')
      end
      nbb   = NotebookBoard.find nbb_id
      board = Board.find nbb.board_id
      list  = List.set_list list_guid, list_name, board
      nbb.set_attrs share_flag, list.id

      synchronizer.sync nbb

      unless list.webhook
        webhook = trello_client.create_webhook list, current_user
        List.set_webhook_attr list, webhook.id if webhook
      end

      list = List.populate_list list, trello_client
    end

    redirect_to new_synchronization_url
  end

  def update
    new_notebooks = params[:notebook_board][:notebook_id].reject(&:blank?)

    unless new_notebooks.empty?
      board = Board.find params[:notebook_board][:id]

      new_notebooks.each do |notebook_params|
        notebook = Notebook.set_notebook notebook_params, current_user.id
        list     = List.where( id: notebook_params.split('|')[2] ).first
        nbb      = NotebookBoard.where(notebook_id: notebook.id, board_id: board.id, list_id: list.id).first

        if nbb
          synchronizer.resync nbb
        end

      end
    end
    redirect_to new_synchronization_url
  end

  def destroy
    synchs     = params[:notebook_board][:notebook].split(',')
    records    = synchs.map { |synch| { notebook_guid: synch.split('|').first, list_id: synch.split('|')[2] } }

    records.each do |record|
      nb_id   = Notebook.where( guid: record[:notebook_guid] ).first.id
      begin
        list_id = List.find(record[:list_id]).id
      rescue ActiveRecord::RecordNotFound
        next
      end
      nbb = NotebookBoard.where(list_id: list_id, notebook_id: nb_id).first

      if nbb
        list = List.find list_id
        nbb.destroy
        list.destroy unless list.still_in_use?
      end
    end
    redirect_to new_synchronization_url anchor: 'synchronizations_wrapper'
  end

  def evernote_listener
    @status = :webhook

    if params[:guid]                                                            # ensure change is to note and not notebook
      notebook  = Notebook.where(guid: params[:notebookGuid]).first
      auth      = Authentication.where(uid: params[:userId]).first
      reason    = params[:reason]
      return head :gone unless notebook && auth

      begin
        user  = User.find auth.user_id
      rescue ActiveRecord::RecordNotFound
        auth.destroy
        return head :gone
      end
      Rails.logger.warn('**** Emptying the trash - BEGIN ****') if user.id == 80
      nbbs  = NotebookBoard.where( notebook_id: notebook.id ).to_a

      sign_in user

      note       = evernote_client.get_note params[:guid]
      title      = note.title.gsub(/\n/, '')
      note_info  = { 'content' => title, 'guid' => params[:guid], "updated" => note.updated.to_s }

      nbbs.each do |nbb|
        list       = List.find nbb.list_id
        cards      = trello_client.get_raw_cards list
        card_guid  = trello_client.find_card_guid note_info, list unless reason == 'create'
        card_info  = { 'content' => title, 'guid' => card_guid }

        if reason == 'create'                                                   # if a new note was created
          Rails.logger.warn('**** Emptying the trash - CREATE ****') if user.id == 80
          update_times  = eval(nbb.compiled_update_times).push(note_info).inspect
          nbb.set_compiled_update_times update_times

          card = trello_client.build_single_card evernote_client, note.notebookGuid, note_info, nbb, list
          card_info['guid'] == card.id

        elsif note.deleted?                                                     # if an existing note was deleted
          Rails.logger.warn('**** Emptying the trash - DELETE ****') if user.id == 80
          card_guid ? trello_client.delete_card(card_guid) : trello_client.find_and_delete_card(cards, title)

        elsif nbb.compiled_update_times.include? note_info['guid']              # if existing note is modified and not moved
          Rails.logger.warn('**** Emptying the trash - MOD TITLE ****') if user.id == 80
          trello_client.update_name title, card_guid

          cards  = cards.reject { |card| card.id == card_guid }
        else                                                                    # if note is moved
          Rails.logger.warn('**** Emptying the trash - MOVE ****') if user.id == 80
          selected_nbbs = user.notebook_boards.select { |the_nbb| the_nbb.compiled_update_times.include? note_info['guid'] }

          selected_nbbs.each do |the_nbb|
            begin
              nbb_notebook = Notebook.find the_nbb.notebook_id
            rescue ActiveRecord::RecordNotFound
              next
            end
            unless nbb_notebook == notebook                                     # remove note from old notebooks

              hash_to_revise = eval the_nbb.compiled_update_times
              revised_list   = hash_to_revise.reject { |h| h['guid'] == note_info['guid'] }
              the_nbb.set_compiled_update_times revised_list.inspect

              old_list   = List.find the_nbb.list_id
              card_guid  = trello_client.find_card_guid note_info, old_list unless card_guid

              if card_guid

                card_info['guid'] = card_guid
                trello_client.delete_card card_guid

                old_list.set_content_string trello_client

              end
            end
          end                                                                   # ...and update new notebook
          trello_client.build_single_card evernote_client, notebook.guid, card_info, nbb, list

          sleep 1
          trello_client.purge_duplicate_cards list
        end

        unless reason == 'create'
          update_times  = evernote_client.build_note_array notebook
          nbb.set_compiled_update_times update_times
        end

        sleep 1
        List.populate_list list, trello_client
      end
      sign_out user
    end
    head :ok
  end

  def trello_listener
    if request.post?
      @status = :webhook
      begin
        user = User.find params[:user_id]
        list = List.find params[:list_id]
      rescue ActiveRecord::RecordNotFound
        return head :gone
      end

      unless list.still_in_use?
        list.update_attributes webhook: nil
        return head :gone
      end

      sign_in user

      nbbs = NotebookBoard.where( list_id: list.id ).to_a
      begin
        list_contents = eval list.contents
      rescue SyntaxError => e
        list.set_content_string trello_client
        list_contents = eval list.contents
      end

      cards = trello_client.get_raw_cards list
      if params['model']['closed'] == true
        nbbs.each { |nbb| nbb.destroy }
        list.destroy
      else
        unless list_contents.blank?
          list_contents.each do |hash|

            unless hash['guid']
              Rails.logger.warn("****** Hash: #{hash.inspect} ******")
              cards = trello_client.get_raw_cards list
              the_card = cards.detect { |card| card.name.include? hash['content'] }
              if the_card
                card_hash = { 'content' => the_card.name, 'guid' => the_card.id }
                new_contents = list_contents << card_hash
                new_contents = new_contents.reject! { |h| h == hash}
                list.update_attributes contents: new_contents.inspect
              else
                new_contents = list_contents.reject! { |h| h == hash}
                list.update_attributes contents: new_contents.inspect
              end

              next
            end

            card_deleted = cards.none? { |card| card.id == hash['guid'] }

            if card_deleted
              the_card = trello_client.get_card hash['guid']

              if the_card.nil? || the_card.list_id == list.guid || the_card.closed == true
                evernote_client.delete_matching_notes hash, nbbs

              else
                new_list = List.where(guid: the_card.list_id).first
                if new_list
                  card_hash = { 'content' => the_card.name, 'guid' => the_card.id }
                  List.add_contents_item new_list, card_hash, trello_client
                  old_nbbs = NotebookBoard.where(list_id: list.id).to_a
                  note_guid = nil
                  unless old_nbbs.empty?
                    old_nbbs.each do |old_nbb|
                      update_times = eval old_nbb.compiled_update_times
                      note_hash = update_times.detect { |h| h['content'] == hash['content'] }
                      note_guid ||= note_hash['guid']
                      revised_list = update_times.reject { |h| h == note_hash }.inspect
                      old_nbb.set_compiled_update_times revised_list
                    end
                  end

                  new_nbb = NotebookBoard.where(list_id: new_list.id).first
                  new_notebook = Notebook.find new_nbb.notebook_id
                  note = evernote_client.get_note note_guid
                  if note
                    note.notebookGuid = new_notebook.guid
                    updated_note = evernote_client.update_note note
                    note_hash = { 'content' => the_card.name, 'guid' => note_guid }
                    trello_client.update_description(evernote_client, note_hash, new_notebook.guid, new_nbb.share_flag, the_card.id)
                  end
                end
              end
              List.remove_contents_item list, hash, trello_client
            end
          end
        end

        cards.each do |card|
          update = list_contents.detect { |hash| card.id == hash['guid'] and card.name != hash['content'] }
          create = list_contents.none? { |hash| card.id == hash['guid'] }
          desc = card.desc
          if update
            List.update_contents_item list, update, trello_client, desc
            evernote_client.update_matching_notes update, nbbs, list
          elsif create
            hashed_card = { 'content' => card.name, 'guid' => card.id }
            List.add_contents_item list, hashed_card, trello_client
            evernote_client.create_matching_notes hashed_card, nbbs, desc
          end
        end
      end
      sign_out user
    end
    head :ok
  end

  private

  def trello_client
    TrelloClient.new current_user.trello
  end

  def evernote_client
    EvernoteClient.new current_user.evernote
  end

  def synchronizer
    Synchronizer.new trello_client, evernote_client
  end

  def board_list
    @board_list ||= trello_client.boards.sort_by { |b| b.name.downcase }
  end
  helper_method :board_list

  def notebook_list
    @notebook_list ||= evernote_client.notebooks.sort_by { |n| n.name.downcase }
  end
  helper_method :notebook_list

  def board_match
    @board_match ||= Board.set_board( params[:notebook_board][:board_id], current_user.id )
  end
  helper_method :board_match

  def notebook_board
    NotebookBoard.new
  end
  helper_method :notebook_board

  def notebook
    Notebook.new
  end
  helper_method :notebook

  def notebook_set
    @notebook_set ||= []
  end
  helper_method :notebook_set

  def nbbs
    @nbbs ||= []
  end
  helper_method :nbbs

  def paramify(records)
    records.map{ |item| item.id }.join(',')
  end

  def unparamify(ids, model)
    ids.split(',').map { |id| model.find id.to_i }
  end

  def notebook_boards
    NotebookBoard.where(user_id: current_user.id).to_a.uniq{ |nbb| nbb.board_id }
  end
  helper_method :notebook_boards

  def board_lists
    @board_lists ||= trello_client.lists board_match.guid
  end
  helper_method :board_lists

  def list_name(notebook_board)
    list = List.find notebook_board.list_id
    list.name
  end
  helper_method :list_name

  def find_notebook_guids(board_id)
    synchronizations = NotebookBoard.where(board_id: board_id).to_a

    synchronizations.map{ |synch| get_notebook_info synch }
  end
  helper_method :find_notebook_guids

  def get_notebook_info(synch)
    notebook = Notebook.find synch.notebook_id
    "#{ notebook.guid }|#{ notebook.name }" + get_list_info(notebook.guid, synch.board_id)
  end

  def get_board_name(board_id)
    Board.find(board_id).name
  end
  helper_method :get_board_name

  def get_list_info(notebook_guid, board_id)
    notebook_id  = Notebook.where(guid: notebook_guid).first.try(:id)
    return '' unless notebook_id
    the_nbb = NotebookBoard.where(notebook_id: notebook_id, board_id: board_id).first
    if the_nbb
      list = List.find the_nbb.list_id
    else
      return ''
    end

    "|#{list.id}|#{list.guid}"
  end
  helper_method :get_list_info

end