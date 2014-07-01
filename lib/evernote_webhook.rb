# handles processing of all Evernote webhook notifications
module EvernoteWebhook
  def self.process_evernote_hook(params, _)
    if params[:guid]
      auth       = Authentication.find_by uid: params[:userId]
      @user      = User.find auth.user_id
      notebook   = Notebook.find_by guid: params[:notebookGuid]
      nbbs       = NotebookBoard.where(notebook_id: notebook.id).to_a if notebook

      if notebook.nil? || nbbs.blank?
        delete_removed_notes params[:guid]
        return
      end

      note, note_info = set_note_info params[:guid]

      nbbs.each do |nbb|
        reason         = set_reason(note, nbb, params)
        _, cards       = set_nbb_vars nbb
        existing_card  = cards.detect { |h| h['content'] == note_info['content'] }

        case reason
        when :noteCreated
          create_card_from_hook(nbb, note_info) unless existing_card
        when :noteDeleted
          delete_card_from_hook(nbb, note_info) if existing_card
        when :noteUpdated
          update_card_from_hook(nbb, note_info) unless existing_card
        when :noteMoved
          move_card_from_hook(nbb, note_info, existing_card)
        end
      end
    end
  end

  private

  def self.create_card_from_hook(nbb, note_info)
    list, cards, notes = set_nbb_vars nbb
    new_card   = TrelloClient.build_single_card(note_info, nbb)

    new_times  = notes.push(note_info).inspect
    nbb.set_compiled_update_times new_times

    card_hash  = { 'content' => new_card.name,
                   'guid'    => new_card.id,
                   'desc'    => new_card.desc
                 }
    contents   = cards.push(card_hash).inspect

    list.update_attributes contents: contents
  end

  def self.delete_card_from_hook(nbb, note_info)
    list, cards, notes = set_nbb_vars nbb

    title  = note_info['content']
    card   = trello_client.find_card note_info, cards

    if card['guid']
      trello_client.delete_card card['guid']
    else
      trello_client.find_and_delete_card(cards, title)
    end

    update_times  = notes.reject { |h| h['content'] == title }.inspect
    nbb.set_compiled_update_times update_times

    contents  = cards.reject { |h| h['content'] == title }.inspect
    list.update_attributes contents: contents
  end

  def self.update_card_from_hook(nbb, note_info)
    list, cards, notes = set_nbb_vars nbb
    title  = note_info['content']

    updated_note  = notes.detect { |h| h['guid'] == note_info['guid'] }
    updated_card  = cards.detect { |h| h['content'] == updated_note['content'] }

    if updated_card
      trello_client.update_name(title, updated_card['guid'])

      updated_note['content']  = title
      updated_note['updated']  = note_info['updated']
      nbb.set_compiled_update_times notes.inspect

      updated_card['content']  = title
      list.update_attributes contents: cards.inspect
    end
  end

  def self.move_card_from_hook(nbb, note_info, existing_card)
    selected_nbbs  = find_boards_with_note(note_info['guid'])

    selected_nbbs.each do |the_nbb|
      old_note_set  = eval the_nbb.compiled_update_times

      unless the_nbb.notebook_id == nbb.notebook_id
        revised_set = old_note_set.reject! { |h| h['guid'] == note_info['guid'] }

        old_list      = List.find(the_nbb.list_id)
        old_contents  = eval old_list.contents
        card  = trello_client.find_card note_info, old_contents

        if existing_card
          trello_client.delete_card card['guid']
        else
          move_card(nbb, card, note_info)
        end

        the_nbb.set_compiled_update_times revised_set.inspect

        new_contents = old_contents.reject! { |h| h['guid'] == card['guid'] }
        old_list.update_attributes contents: new_contents.inspect
      end
    end
  end

  def self.move_card(nbb, card, note_info)
    list, cards, notes = set_nbb_vars nbb

    trello_client.move_card(card, list)

    new_times  = notes.push(note_info).inspect
    nbb.set_compiled_update_times new_times

    contents   = cards.push(card).inspect
    list.update_attributes contents: contents
  end

  def self.trello_client
    TrelloClient.new @user.trello
  end

  def self.evernote_client
    EvernoteClient.new @user.evernote
  end

  def self.set_note_info(note_guid)
    note       = evernote_client.get_note note_guid
    note_info  = { 'content' => note.title.chomp,
                   'guid'    => note_guid,
                   'updated' => note.updated.to_s
                 }

    [note, note_info]
  end

  def self.delete_removed_notes(guid)
    nbbs = find_boards_with_note guid

    if nbbs.present?
      _, note_info = set_note_info guid

      nbbs.each { |nbb| delete_card_from_hook(nbb, note_info) }
    end
  end

  def self.set_reason(note, nbb, params)
    new_note             = params[:reason] == 'create'
    updated              = nbb.compiled_update_times.include?(note.guid)
    moved_from_unsynched = find_boards_with_note(note.guid).blank?

    case
    when new_note             then :noteCreated
    when note.deleted?        then :noteDeleted
    when updated              then :noteUpdated
    when moved_from_unsynched then :noteCreated
    else :noteMoved
    end
  end

  def self.set_nbb_vars(nbb)
    list   = List.find(nbb.list_id)
    cards  = eval list.contents
    notes  = eval nbb.compiled_update_times

    [list, cards, notes]
  end

  def self.find_boards_with_note(note_guid)
    user_nbbs  = @user.notebook_boards

    user_nbbs.select do |the_nbb|
      the_nbb.compiled_update_times.include? note_guid
    end
  end
end
