class Board < ActiveRecord::Base
  attr_accessible :name, :description, :guid, :url, :organization_id, :user_id

  validates_uniqueness_of :guid
  validates :user_id, presence: true

  belongs_to :user
  has_many   :notebook_boards
  has_many   :notebooks, :through => :notebook_boards
  has_many   :lists

  def self.set_board( params, user_id )
    # format params into a readable array
    board_guid, board_name = params.split('|')
    # if board exists as a record, use it. If not, create it.
    board = find_board_by_guid board_guid
    board ||= Board.create( name: board_name, guid: board_guid, user_id: user_id )
  end

  def self.find_board_by_guid( guid )
    Board.where( guid: guid ).first
  end

end
