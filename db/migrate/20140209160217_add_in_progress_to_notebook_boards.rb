class AddInProgressToNotebookBoards < ActiveRecord::Migration
  def change
    add_column :notebook_boards, :in_progress, :string, array: true, default: []
  end
end
