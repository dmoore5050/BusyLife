class List < ActiveRecord::Base
  attr_accessible :name, :guid, :contents, :board_id, :webhook

  validates_uniqueness_of :guid
  validates :guid,     presence: true
  validates :name,     presence: true
  validates :board_id, presence: true

  has_many   :notebook_boards
  belongs_to :board

  def self.populate_list(list, trello_client)
    list.set_content_string trello_client
    list
  end

  def set_content_string(trello_client)
    content_string = trello_client.create_content_string self
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

  def self.remove_contents_item(list, card)
    contents = eval list.contents
    contents.delete_if { |h| h['guid'] == card['guid'] }
    list.update_attributes contents: contents.inspect
  end

  def self.update_contents_item(list, card)
    contents = eval list.contents
    item = contents.detect { |h| h['guid'] == card['guid'] }
    if item
      item['content'] = card['content']
      list.update_attributes contents: contents.inspect
    end
  end

  def self.add_contents_item(list, card)
    contents = eval list.contents
    contents << { 'content' => card['content'], 'guid' => card['guid'] }
    list.update_attributes contents: contents.inspect
  end

  def still_in_use?
    NotebookBoard.where(list_id: self.id).all.present?
  end
end