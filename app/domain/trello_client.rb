require 'trello'

class TrelloClient
  attr_accessor :user_auth, :client

  def initialize(auth)
    @user_auth = auth
    client
  end

  def client
    @client ||= Trello::Client.new :consumer_key => AppConfig['trello_key'],
                                    :consumer_secret => AppConfig['trello_secret'],
                                    :oauth_token => @user_auth.token,
                                    :oauth_token_secret => @user_auth.token_secret

  end

  def create_webhook(list, user)
    callback_url = "http://my.busylife.co/synchronizations/trello_listener?list_id=#{ list.id }&user_id=#{ user.id }"
    description  = "Webhook for list #{ list.id }: #{ list.name }"

    client.create :webhook,
      'description' => description,
      'idModel'     => list.guid,
      'callbackURL' => callback_url
  rescue Trello::Error => err
    puts err.inspect
  end

  def boards
    client.find( 'member', 'me' ).boards( closed: false )
  rescue Trello::Error => err
    puts err.inspect
  end

  def lists(guid)
    lists = client.find(:board, guid).lists( closed: false )
    lists_data = []
    lists.each { |list| lists_data << { name: list.name, id: list.id } }

    lists_data
  end

  def create_list(name, board_id)
    client.create :list,
      'name'    => name,
      'idBoard' => board_id
  rescue Trello::Error => err
    puts err.inspect
  end

  def get_card(id, params = {})
    client.find(:card, id, params)
  rescue Trello::Error => err
    puts err.inspect
  end

  def get_raw_cards(list)
    client.find( :list, list.guid ).cards( closed: false )
  rescue Trello::Error => err
    puts err.inspect
  end

  def cards(list)
    cards = get_raw_cards list

    cards = cards.map { |c| { 'content' => c.name, 'desc' => c.desc } }
    cards = cards.reject { |c| c['content'].blank? }

    cards.uniq
  end

  def find_card_guid(note_guid, list)
    cards = get_raw_cards list

    cards.each do |card|
      return card.id if card.desc.include? note_guid
      nil if card == cards.last
    end
  end

  def update_name(name, card_guid)
    payload = { :name => name }
    client.put("/cards/#{ card_guid }", payload)
  rescue Trello::Error => err
    puts err.inspect
  end

  def update_list #used for testing
    payload = { :idList => "5298f71b6146fa1b050083f0" }
    client.put("/cards/52b609e289920dca68003827", payload)
  rescue Trello::Error => err
    puts err.inspect
  end

  def update_description(evernote_client, note, notebook_guid, share_flag, card_guid)
    description = build_card_description(evernote_client, note, notebook_guid, share_flag)
    payload = { :desc => description }
    client.put("/cards/#{ card_guid }", payload)
  rescue Trello::Error => err
    puts err.inspect
  end

  def remove_outdated_cards(notes, list)
    cards = get_raw_cards list

    cards.each do |card|
      Array.wrap(notes).each do |note|
        delete_card card.id if card.desc.include? note['guid']
      end
    end
  end

  def create_content_string(list)
    cards = get_raw_cards list
    card_contents = []
    cards.each do |card|
      card_contents << { 'content' => card.name, 'guid' => card.id }
    end
    card_contents.inspect
  end

  def delete_card(card_guid)
    client.delete "/cards/#{ card_guid }"
  rescue Trello::Error => err
    puts err.inspect
  end

  def sync_trello(cards, notebook_board, evernote_client)
    notes = eval notebook_board.compiled_update_times
    notebook = Notebook.find notebook_board.notebook_id
    note_contents = notes.map { |note| { 'content' => note['content'] } }
    card_contents = cards.map { |card| { 'content' => card['content'] } }

    cards_to_create = note_contents - card_contents
    notes.each do |note|
      if cards_to_create.any? { |h| h['content'] == note['content'] }
        build_single_card evernote_client, notebook.guid, note, notebook_board
      end
    end
  end

  def build_single_card(evernote_client, notebook_guid, note, notebook_board)
    list = List.find notebook_board.list_id
    description = build_card_description evernote_client, note, notebook_guid, notebook_board.share_flag
    create_card note, list, description
  end

  def create_card(note, list, description)
    client.create :card,
      'name' => note['content'],
      'idList' => list.guid,
      'desc' => description
  rescue Trello::Error => err
    puts err.inspect
  end

  def build_card_description(evernote_client, note, notebook_guid, share_flag)
    share_url = evernote_client.share_single_note note['guid'] if share_flag
    desc = "\r\n\r\n\r\n[Get your free visual workflow at my.BusyLife.co ](http://my.busylife.co)\r\n\r\n"
    desc << "Change note in Evernote. Text here is for reference only.\r\n"
    desc << "Please use one of the following links to see the full note:\r\n\r\n"
    desc << "Notebook Id: #{ notebook_guid }\r\n"
    desc << "Note Id: #{ note['guid'] }\r\n\r\n"
    desc << "[Link to View/Edit your own or a shared notebook in Evernote ](https://www.evernote.com/Home.action#n=#{note[:note_guid]} \"\"\"\" target=\"_blank\" )\r\n\r\n\r\n"
    desc << "[Link to View Note ](#{ share_url })\r\n\r\n\r\n" if share_flag
    # replace &'s to prevent 'entity name must immediately follow body' error
    desc = desc.gsub(/[&]/, '&amp;')
  end

end