class Synchronizer
  attr_reader :trello_client, :evernote_client

  def initialize(trello_client, evernote_client)
    @trello_client   = trello_client
    @evernote_client = evernote_client
  end

  def sync(notebook_board)
    notebook, list = set_sync_vars notebook_board
    cards = trello_client.cards list
    create_cards_and_notes cards, notebook_board, notebook
  end

  def resync(notebook_board)
    notebook, list = set_sync_vars notebook_board
    updated_notes  = eval notebook_board.compiled_update_times
    trello_client.remove_outdated_cards updated_notes, list
    cards = trello_client.cards list
    create_cards_and_notes cards, notebook_board, notebook
  end

  def set_sync_vars(notebook_board)
    notebook = Notebook.find notebook_board.notebook_id
    list     = List.find notebook_board.list_id
    [notebook, list]
  end

  def create_cards_and_notes(cards, notebook_board, notebook)
    trello_client.sync_trello cards, notebook_board, evernote_client
    evernote_client.sync_evernote cards, notebook_board
  end

end