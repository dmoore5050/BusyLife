class Synchronizer
  attr_reader :trello_client, :evernote_client, :list, :notebook

  def initialize(trello_client, evernote_client)
    @trello_client   = trello_client
    @evernote_client = evernote_client
  end

  def sync(notebook_board)
    set_sync_vars notebook_board

    build_content_strings notebook_board, notebook
    cards = trello_client.cards list

    create_cards_and_notes cards, notebook_board, notebook
  end

  def resync(notebook_board)
    set_sync_vars notebook_board

    update_content_strings notebook_board

    updated_notes = eval notebook_board.compiled_update_times
    trello_client.remove_outdated_cards updated_notes, list
    cards = trello_client.cards list

    create_cards_and_notes cards, notebook_board, notebook
  end

  def set_sync_vars(notebook_board)
    @notebook = Notebook.find notebook_board.notebook_id
    @list     = List.find notebook_board.list_id
  end

  def create_cards_and_notes(cards, notebook_board, notebook)
    trello_client.sync_trello cards, notebook_board, evernote_client
    evernote_client.sync_evernote cards, notebook_board

    update_content_strings notebook_board
  end

  def build_content_strings(notebook_board, notebook)
    notes = evernote_client.build_note_array notebook
    notebook_board.set_compiled_update_times notes

    list.set_content_string trello_client
  end

  def update_content_strings(notebook_board)
    notes = evernote_client.update_note_array notebook_board
    notebook_board.set_compiled_update_times notes

    list.set_content_string trello_client
  end
end