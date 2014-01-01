class SynchronizationsController < ApplicationController
  before_filter :authenticate_user!, except: [:trello_listener, :evernote_listener, :pingdom_listener]

  def new
    NotebookBoard.validate_records
  end

  def create
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

  def edit
    share_flag   = params[:notebook_board][:share_flag]
    synch_params = params[:notebook_board][:list_id]
    list_params  = params[:new_list_params]

    synch_params.each_with_index do |(_, value), i|
      if value.blank?
        list_name, board_guid, nbb_id, notebook_guid = list_params["#{i}"].split('|')
        trello_list = trello_client.create_list list_name, board_guid
        list_guid = trello_list.id
      else
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
      notebook_board = NotebookBoard.find params[:notebook_board][:id]
      new_notebooks.each do |notebook_params|
        notebook = Notebook.set_notebook notebook_params, current_user.id

        if notebook.id == notebook_board.notebook_id
          revised_notes = evernote_client.update_note_array notebook_board
          notebook_board.set_compiled_update_times revised_notes
          synchronizer.resync notebook_board
        elsif new_notebooks.length > 1
          new_nbb = notebook_board.dup
          new_nbb.update_attributes notebook_id: notebook.id
          notes = evernote_client.build_note_array notebook
          new_nbb.set_compiled_update_times notes
          synchronizer.sync new_nbb
        else
          notes = evernote_client.build_note_array notebook
          notebook_board.set_compiled_update_times notes
          notebook_board.update_attributes notebook_id: notebook.id
          synchronizer.sync notebook_board
        end
      end
    end
    redirect_to new_synchronization_url
  end

  def destroy
    board_id = params[:notebook_board][:board]
    notebook_ids = params[:notebook_board][:notebook].split(',')
      .map! { |nbb| Notebook.where( guid: nbb.split('|').first ).first.id }

    notebook_ids.each do |nb_id|
      nbb = NotebookBoard.where(board_id: board_id).where(notebook_id: nb_id).first
      nbb.destroy if nbb
    end
    redirect_to new_synchronization_url anchor: 'synchronizations_wrapper'
  end

  def evernote_listener
    if params[:guid]
      note_guid  = params[:guid]
      reason     = params[:reason]
      uid        = params[:userId]
      notebook   = Notebook.where(guid: params[:notebookGuid]).first
      auth       = Authentication.where(uid: uid).first
      return head :gone unless notebook && auth

      begin
        user     = User.find auth.user_id
      rescue ActiveRecord::RecordNotFound
        auth.destroy
        return head :gone
      end
      nbbs       = NotebookBoard.where( notebook_id: notebook.id ).all
      sign_in user
      note       = evernote_client.get_note note_guid

      nbbs.each do |nbb|
        nb_hash   = eval nbb.compiled_update_times
        list      = List.find nbb.list_id
        card_guid = trello_client.find_card_guid note_guid, list
        card_info = { 'content' => note.title, 'guid' => card_guid }

        if reason ==  'create' || reason == 'business_create' || card_guid.nil?
          nb_hash << evernote_client.new_note_hash(note)
          trello_client.build_single_card evernote_client, note.notebookGuid, card_info, nbb
          List.add_contents_item list, card_info
        elsif reason == 'update' || reason == 'business_update'
          if note.deleted?
            revised_list = nb_hash.reject { |h| h['guid'] == note_guid }
            nbb.set_compiled_update_times revised_list
            trello_client.delete_card card_guid
            List.remove_contents_item list, card_info
          elsif nbb.compiled_update_times.include? note_guid
            nb_hash = evernote_client.modify_comparison_string note, nb_hash
            trello_client.update_name note.title, card_guid
            update = List.update_contents_item list, card_info
            List.add_contents_item list, card_info unless update
          else
            selected_nbbs = user.notebook_boards.select { |the_nbb| the_nbb.compiled_update_times.include? note_guid }
            unless selected_nbbs.empty?
              selected_nbbs.each do |the_nbb|
                begin
                  user_notebook = Notebook.find the_nbb.notebook_id
                rescue ActiveRecord::RecordNotFound
                  user_notebook = Notebook.create( guid: the_nbb.notebook_id, user_id: current_user.id )
                end
                unless user_notebook.guid == params[:notebookGuid]
                  hash_to_revise = eval the_nbb.compiled_update_times
                  revised_list = hash_to_revise.reject { |h| h['guid'] == note_guid }
                  the_nbb.set_compiled_update_times revised_list

                  trello_client.delete_card card_guid
                  List.remove_contents_item list, card_info
                else
                  nb_hash << evernote_client.new_note_hash(note)
                  trello_client.build_single_card evernote_client, note.notebookGuid, card_info, the_nbb
                  List.add_contents_item list, card_info
                end
              end
            end
          end
        end
        nbb.set_compiled_update_times nb_hash.inspect
      end
      sign_out user
    end

    head :ok
  end

  def trello_listener
    if request.post?
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

      nbbs          = NotebookBoard.where( list_id: list.id ).all
      list_contents = eval list.contents
      cards         = trello_client.get_raw_cards list
      if params['model']['closed'] == true
        nbbs.each { |nbb| nbb.destroy }
      else
        list_contents.each do |hash|
          card_deleted = cards.none? { |card| card.id == hash['guid'] }
          if card_deleted
            the_card = trello_client.get_card hash['guid']
            if the_card.list_id == list.guid || the_card.closed == true
              evernote_client.delete_matching_notes hash, nbbs
            else
              new_list = List.where(guid: the_card.list_id).first
              if new_list
                card_hash = { 'content' => the_card.name, 'guid' => the_card.id }
                List.add_contents_item(new_list, card_hash)
                old_nbbs = NotebookBoard.where(list_id: list.id).all
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
            List.remove_contents_item list, hash
          end
        end

        cards.each do |card|
          update = list_contents.detect { |hash| card.id == hash['guid'] and card.name != hash['content'] }
          create = list_contents.none? { |hash| card.id == hash['guid'] }
          content = card.desc
          if update
            evernote_client.update_matching_notes update, nbbs, list
            List.update_contents_item list, update
          elsif create
            # check notebook to ensure note doesn't already exist
            hashed_card = { 'guid' => card.id, 'content' => card.name }
            evernote_client.create_matching_notes hashed_card, nbbs, content
            List.add_contents_item list, hashed_card
          end
        end
      end
      sign_out user
    end
    head :ok
  end

  def pingdom_listener
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

  def paramify(array)
    string = ""
    array.each do |item|
      string << item.id.to_s
      string << "," unless item == array.last
    end
    string
  end

  def unparamify(string, model)
    ids = Array.wrap(string.split ",")
    array = []
    ids.each do |id|
      record = model.find id.to_i
      array << record
    end
    array
  end

  def notebook_boards
    NotebookBoard.where(user_id: current_user.id).all.uniq{ |nbb| nbb.board_id }
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
    notebooks = []
    synchchronizations = NotebookBoard.where(board_id: board_id).all
    synchchronizations.each do |synch|
      notebook = Notebook.find synch.notebook_id
      notebooks << "#{ notebook.guid }|#{ notebook.name }"
    end
    notebooks
  end
  helper_method :find_notebook_guids

  def get_board_name(board_id)
    board = Board.find board_id
    board.name if board
  end
  helper_method :get_board_name

end