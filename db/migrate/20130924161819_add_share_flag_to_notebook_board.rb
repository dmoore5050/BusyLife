class AddShareFlagToNotebookBoard < ActiveRecord::Migration
  def change
    add_column :notebook_boards, :share_flag, :boolean
  end
end
