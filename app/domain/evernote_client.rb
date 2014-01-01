require 'render_anywhere'

class EvernoteClient
  include RenderAnywhere
  attr_accessor :user_auth, :client, :user_store, :en_user, :shard_id

  def initialize(auth)
     @user_auth = auth
     client
  end

  def client
    @client ||= EvernoteOAuth::Client.new( token: @user_auth.token,
                                           consumer_key: AppConfig['evernote_key'],
                                           consumer_secret: AppConfig['evernote_secret'],
                                           sandbox: AppConfig['evernote_sandbox'],
                                           service_host: AppConfig['evernote_api_url']
                                          )
  end

  ## See EDAMErrorCode enumeration for error code explanation
  ## http://dev.evernote.com/documentation/reference/Errors.html#Enum_EDAMErrorCode
  def user_store
    @user_store ||= client.user_store
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting user_store: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting user_store: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def note_store
    @note_store ||= client.note_store
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting note_store: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting note_store: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def en_user
    @en_user ||= user_store.getUser(@user_auth.token)
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting en_user: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting en_user: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def shard_id
    @shard_id ||= en_user.shardId
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting shard_id: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting shard_id: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def notebooks
    note_store.listNotebooks
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting notebooks: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Exception(System) getting notebooks: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def total_note_count(notebook)
    response = note_store.findNoteCounts(@user_auth.token, filter(notebook.guid), false)
    count = response.notebookCounts[notebook.guid] if response.notebookCounts
    count ? count : 0
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting notes count: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting notes count: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def get_note(note_guid)
    note_store.getNote(@user_auth.token, note_guid, true, false, false, false)
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting note: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting note: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  rescue Evernote::EDAM::Error::EDAMNotFoundException => ednfe
    puts "Error(NotFound) sharing note: #{ednfe.inspect}"
  end

  def build_note_array(notebook)
    notes_array = retrieve_raw_notes(0, notebook)
    notes = modify_comparison_string notes_array, []

    # ensure that getNotes has retrieved all the notes available
    # http://discussion.evernote.com/topic/14303-grab-all-notes-in-a-notebook/?p=131079
    complete_notes = notes + get_unretrieved_notes(notebook, notes_array.length)
    complete_notes.compact.uniq {|h| h['content'] }.delete_if { |h| invalid h['content'] }.inspect
  end

  def update_note_array(notebook_board)
    stored_update_times = eval(notebook_board.compiled_update_times)
    notebook = Notebook.find notebook_board.notebook_id
    notes_array = retrieve_raw_notes(0, notebook)

    updated_notes = modify_comparison_string notes_array, stored_update_times
    updated_notes += get_unretrieved_notes notebook, notes_array.length

    updated_notes.compact.uniq {|h| h['content'] }.delete_if { |h| invalid h['content'] }.inspect
  end

  def modify_comparison_string(notes_array, stored_update_times)
    Array.wrap(notes_array).each do |note|
      note_content = note.title.gsub(/\n/, '')
      next if invalid note_content

      hash = stored_update_times.compact.detect { |h| h['guid'] == note.guid }
      if hash.nil?
        stored_update_times << new_note_hash(note)
      elsif hash["updated"] != note.updated
        hash["updated"] = note.updated
        hash["content"] = note_content
      end
    end

    stored_update_times
  end

  def new_note_hash(note)
    note_content = note.title.gsub(/\n/, '')
    return nil if invalid note_content
    { "content" => note_content, "guid" => note.guid, "updated" => note.updated.to_s }
  end

  def retrieve_raw_notes(offset, notebook)
    Array.wrap(note_store.findNotes(@user_auth.token, filter(notebook.guid), offset, 100).notes)
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) getting raw notes: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) getting raw notes: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def get_unretrieved_notes(notebook, notes_length, count = nil)
    note_count = count ? count : total_note_count(notebook)
    collection ||= []
    if notes_length < note_count
      offset = note_count - notes_length
      notes_array = retrieve_raw_notes offset, notebook
      collection += modify_comparison_string(notes_array, collection) if notes_array.present?
      notes_length += notes_array.length
      get_unretrieved_notes notebook, notes_length, note_count
    end

    collection
  end

  def filter(guid)
    Evernote::EDAM::NoteStore::NoteFilter.new(notebookGuid: guid)
  end

  def share_single_note(note_guid)
    share_key = note_store.shareNote note_guid
    "https://www.evernote.com/shard/#{ shard_id }/sh/#{ note_guid }/#{ share_key }"
  rescue Evernote::EDAM::Error::EDAMNotFoundException => ednfe
    puts "Error(NotFound) sharing note: #{ednfe.inspect}"
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) sharing note: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) sharing note: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def sync_evernote(cards, notebook_board)
    notebook = Notebook.find notebook_board.notebook_id
    notes = eval notebook_board.compiled_update_times

    note_contents = notes.map{ |note| { 'content' => note['content'] } }
    card_contents = cards.map{ |card| { 'content' => card['content'] } }
    new_notes = cards-note_contents

    new_notes.each do |note|
      card      = cards.find{ |c| c['content'] == note['content'] }
      card_desc = card['desc'] unless card['desc'].blank?
      create_note note, notebook, card_desc
    end
  end

  def create_note(note, notebook, card_desc)
    card_desc   = "This note copied from Trello by BusyLife." if card_desc.blank?
    the_content = "<?xml version='1.0' encoding='UTF-8'?>"
    the_content << "<!DOCTYPE en-note SYSTEM 'http://xml.evernote.com/pub/enml2.dtd'>"
    the_content << "<en-note>#{card_desc}</en-note>"

    the_note              = Evernote::EDAM::Type::Note.new
    the_note.title        = note['content']
    the_note.content      = the_content
    the_note.notebookGuid = notebook.guid

    note_store.createNote(@user_auth.token, the_note)
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) creating note: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) creating note: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMNotFoundException => ednfe
    puts "Error(NotFound) creating note: #{ednfe.inspect}"
  end

  def create_matching_notes(card, nbbs, card_desc)
    nbbs.each do |nbb|
      nb_contents = eval nbb.compiled_update_times
      unless nb_contents.any? { |n| n['content'] == card['content'] }
        notebook = Notebook.find nbb.notebook_id
        updated_note = create_note card, notebook, card_desc
        updated_times = modify_comparison_string updated_note, nb_contents
        nbb.set_compiled_update_times updated_times.inspect
      end
    end
  end

  def update_matching_notes(card, nbbs, list)
    list_contents = eval list.contents
    list_item = list_contents.detect { |h| h['guid'] == card['guid'] }
    if list_item
      nbbs.each do |nbb|
        nb_contents = eval nbb.compiled_update_times
        notebook_item = nb_contents.detect { |h| h['content'] == list_item['content'] }
        note = get_note notebook_item['guid'] if notebook_item
        if note
          note.title = card['content']
          updated_note = update_note note
          updated_times = modify_comparison_string updated_note, nb_contents
          nbb.set_compiled_update_times updated_times.inspect
        end
      end
    else
      create_matching_notes card, nbbs
    end
  end

  def delete_matching_notes(card, nbbs)
    nbbs.each do |notebook_board|
      update_times = eval notebook_board.compiled_update_times
      note = update_times.detect { |h| h['content'] == card['content'] }

      delete_note note['guid'] if note

      revised_list = update_times.reject { |h| h == note }.inspect
      notebook_board.set_compiled_update_times revised_list
    end
  end

  def update_note(note)
    note_store.updateNote(@user_auth.token, note)
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) updating note: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) updating note: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  def delete_note(note_guid)
    note_store.deleteNote(@user_auth.token, note_guid)
  rescue Evernote::EDAM::Error::EDAMUserException => edue
    puts "Error(User) deleting note: #{edue.inspect}"
  rescue Evernote::EDAM::Error::EDAMSystemException => edse
    puts "Error(System) deleting note: #{edse.inspect}"
    return render :template => '/synchronizations/error', :layout => 'application'
  end

  private

  def invalid(string)
    return true if string.blank? || string == "Untitled"
    false
  end
end