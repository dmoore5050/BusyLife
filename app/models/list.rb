class List < ActiveRecord::Base
  attr_accessible :name, :guid, :contents, :board_id, :webhook

  validates_uniqueness_of :guid
  validates :guid,     presence: true
  validates :name,     presence: true
  validates :board_id, presence: true

  has_many   :notebook_boards
  belongs_to :board

  def self.populate_list(list, trello_client, cards = nil)
    list.set_content_string trello_client, cards
    list
  end

  def set_content_string(trello_client, cards = nil)
    content_string = trello_client.create_content_string self, cards
    self.update_attributes( contents: content_string )
  end

  def self.set_webhook_attr(list, webhook_id)
    list.update_attributes webhook: webhook_id
  end

  def self.set_list(guid, name, board)
    the_list = find_list_by_guid guid
    the_list ||= List.create( guid: guid, name: name, board_id: board.id )
  end

  def self.find_list_by_guid(guid)
    List.where( guid: guid ).first
  end

  def self.remove_contents_item(list, card, trello_client)
    begin
      contents = eval list.contents
    rescue SyntaxError, TypeError => e
      list.set_content_string trello_client
      contents = eval list.contents
    end

    contents.delete_if { |h| h['guid'] == card['guid'] }
    list.update_attributes contents: contents.inspect
  end

  def self.update_contents_item(list, card, trello_client, desc = nil)
    begin
      contents = eval list.contents
    rescue SyntaxError, TypeError => e
      list.set_content_string trello_client
      contents = eval list.contents
    end

    item = contents.detect { |h| h['guid'] == card['guid'] }
    if item
      item['content'] = card['content']
      item['desc'] = desc if desc
      list.update_attributes contents: contents.inspect
    end
  end

  def self.add_contents_item(list, card, trello_client, desc = nil)
    begin
      contents = eval list.contents
    rescue SyntaxError, TypeError => e
      list.set_content_string trello_client
      contents = eval list.contents
    end

    hash = { 'content' => card['content'], 'guid' => card['guid'] }
    hash['desc'] = desc if desc

    contents << hash
    list.update_attributes contents: contents.inspect
  end

  def still_in_use?
    NotebookBoard.where(list_id: self.id).to_a.present?
  end
end