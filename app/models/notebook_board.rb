class NotebookBoard < ActiveRecord::Base
  attr_accessible :notebook_id, :board_id, :list_id, :user_id, :compiled_update_times, :share_flag

  validates :notebook_id, presence: true
  validates :board_id,    presence: true
  validates :user_id,     presence: true
  validates_uniqueness_of :list_id, scope: [:notebook_id]

  belongs_to :notebook
  belongs_to :board
  belongs_to :user
  belongs_to :list

  def self.set_notebook_board( board, notebook, update_string )
    the_nbb = NotebookBoard.where(board_id: board.id, notebook_id: notebook.id, list_id: nil).first
    the_nbb ||= NotebookBoard.create(notebook_id: notebook.id, board_id: board.id, compiled_update_times: update_string, user_id: board.user_id)
  end

  def set_attrs(share_flag, list_id)
    self.update_attributes(share_flag: share_flag, list_id: list_id)
    self
  end

  def set_compiled_update_times( list )
    self.update_attributes(compiled_update_times: list)
    self
  end

  def self.validate_records
    invalid_records = NotebookBoard.where(list_id: nil).all
    invalid_records.each do |record|
      record.destroy
    end
  end
end