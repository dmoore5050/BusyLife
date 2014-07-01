# handles processing of all Trello webhook notifications
module TrelloWebhook
  def self.process_trello_hook(params, _)
    @user  = User.find params[:user_id]

    list_id = params[:list_id]
    list    = List.find list_id if list_id
    list  ||= List.find_by guid: params[:model][:idList]

    closed        = params['model']['closed']
    nbbs          = NotebookBoard.where(list_id: list.id).to_a
    list_contents = eval list.contents

    unless list_id
      model      = params[:model]
      card_hash  = { 'content' => model[:name], 'guid' => model[:id], 'desc' => model[:desc] }
      updated    = list_contents.detect { |h| h['guid'] == card_hash['guid'] }
    end

    nbbs.each do |nbb|
      notes     = eval nbb.compiled_update_times

      unless list_id
        note_guid     = evernote_client.find_note_guid(card_hash, notes)
        existing_note = notes.detect { |note| note['content'] == card_hash['content'] }
      end

      reason = set_reason(list_id, list_contents, card_hash, closed, note_guid)

      case reason
      when :listDeleted
        list.destroy
        break
      when :listModified
        break
      when :cardCreated
        create_note_from_hook(nbb) unless existing_note
      when :cardDeleted
        if existing_note
          if note_guid
            evernote_client.delete_note(note_guid)
          else
            evernote_client.find_and_delete_note(notes, card_hash['content'])
          end

          revised_cards = list_contents.reject! { |card| card['guid'] == card_hash['guid'] }
          list.update_attributes(contents: revised_cards.inspect)

          revised_notes = notes.reject! { |note| note['guid'] == note_guid }
          nbb.set_compiled_update_times revised_notes.inspect
        end
      when :cardUpdated
        the_card   = list_contents.detect { |h| h['guid'] == card_hash['guid']}
        note_guid  = evernote_client.find_note_guid(the_card, notes)
        if note_guid
          note       = evernote_client.get_note note_guid

          content_changed = card_hash['content'] != updated['content']
          desc_changed    = card_hash['desc']    != updated['desc']
          titled          = card_hash['content'] != 'Untitled'

          if content_changed && titled
            flag        = true
            note.title  = card_hash['content']
          end

          if desc_changed
            flag          = true
            card_desc     = evernote_client.format_card_description card_hash['desc']
            note.content  = card_desc if card_desc
          end

          if flag
            evernote_client.update_note note

            c_hash  = list_contents.detect{ |h| h['guid'] == card_hash['guid'] }
            c_hash['content']  = card_hash['content']
            c_hash['desc']     = card_hash['desc']
            list.update_attributes contents: list_contents.inspect

            n_hash  = notes.detect { |h| h['guid'] == note_guid }
            n_hash['content']  = card_hash['content']
            nbb.set_compiled_update_times notes.inspect
          else
            next
          end
        end
      when :cardMoved
        move_note_from_hook(card_hash, note_guid, nbb)
      end
    end
  end

  private

  def self.create_note_from_hook(nbb)
    notes          = eval nbb.compiled_update_times
    notebook       = Notebook.find nbb.notebook_id
    list           = List.find nbb.list_id
    list_contents  = eval list.contents
    cards          = trello_client.get_raw_cards(list)

    card_titles  = list_contents.map { |h| h['content'] }
    the_card     = cards.detect { |card| card_titles.exclude? card.name }

    if the_card
      card_hash  = { 'content' => the_card.name,
                     'guid'    => the_card.id,
                     'desc'    => the_card.desc
                   }
      trello_client.create_card_webhook the_card, @user.id

      moved_card    = moved_card?(card_hash)
      updated_card  = list_contents.detect { |h| h['guid'] == the_card.id }
      untitled      = card_hash['content'] == 'Untitled'
      existing_note = eval(nbb.compiled_update_times).detect { |note| note['content'] == card_hash['content'] }

      unless existing_note || updated_card || untitled || moved_card

        note  = evernote_client.create_note card_hash, notebook, card_hash['desc']

        return if note == 'invalid token'

        queue  = nbb.user_id.to_s.chars.last
        EvernoteClient.delay(queue: "sync_#{queue}").add_share_link_to_existing_card(note.guid, card_hash['guid'], card_hash['desc'], nbb.id)

        list_contents  = list_contents.push(card_hash)
        list.update_attributes contents: list_contents.inspect

        note_hash = { 'content' => the_card.name,
                      'guid'    => note.guid,
                      'updated' => note.updated
                    }
        updated_notes = notes.push(note_hash).inspect
        nbb.set_compiled_update_times updated_notes
      end
    end
  end

  def self.move_note_from_hook(card_hash, note_guid, nbb)
    list   = List.find nbb.list_id
    @flag  = nil
    selected_nbbs = find_boards_with_card(card_hash)

    selected_nbbs.each do |the_nbb|
      nbb_list = List.find the_nbb.list_id

      unless nbb_list == list
        nbb_arr    = eval the_nbb.compiled_update_times
        note_guid  = evernote_client.find_note_guid card_hash, nbb_arr

        if note_guid
          @flag = copy_note(note_guid, card_hash, nbb) unless @flag

          evernote_client.delete_note note_guid

          hash_to_revise  = eval nbb_list.contents
          revised_list    = hash_to_revise.reject { |h| h['guid'] == card_hash['guid'] }.inspect
          nbb_list.update_attributes(contents: revised_list)

          nbb_arr = nbb_arr.reject { |h| h['guid'] == note_guid }.inspect
          the_nbb.set_compiled_update_times nbb_arr
        end
      end
    end
  end

  def self.copy_note(note_guid, card_hash, nbb)
    notebook  = Notebook.find nbb.notebook_id
    list      = List.find nbb.list_id

    note  = evernote_client.copy_note note_guid, notebook

    list_contents  = eval(list.contents).push(card_hash).inspect
    list.update_attributes contents: list_contents

    note_hash = { 'content' => note.title,
                  'guid'    => note.guid,
                  'updated' => note.updated
                }

    nbb_contents  = eval(nbb.compiled_update_times).push(note_hash).inspect
    nbb.set_compiled_update_times nbb_contents

    :complete
  end

  def self.find_boards_with_card(card_hash)
    user_nbbs  = @user.notebook_boards

    user_nbbs.select do |the_nbb|
      List.find(the_nbb.list_id).contents.include? card_hash['guid']
    end
  end

  def self.trello_client
    TrelloClient.new @user.trello
  end

  def self.evernote_client
    EvernoteClient.new @user.evernote
  end

  def self.set_reason(list_id, list_contents, card_hash, closed, note_guid)
    closed_list = list_id && closed
    new_card    = list_id && note_guid.nil?
    updated     = list_contents.detect { |h| h['guid'] == card_hash['guid'] } unless list_id

    case
    when closed_list  then :listDeleted
    when new_card     then :cardCreated
    when list_id      then :listModified
    when closed       then :cardDeleted
    when updated      then :cardUpdated
    else :cardMoved
    end
  end

  def self.moved_card?(card_hash)
    !find_boards_with_card(card_hash).blank?
  end
end
