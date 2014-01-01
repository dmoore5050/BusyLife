class AddUserIdToNotebooksAndBoards < ActiveRecord::Migration
  def change
  	add_column :notebooks, :user_id, :integer
  	add_column :boards, :user_id, :integer
  	add_index  :notebooks, :user_id
  	add_index  :boards, :user_id
  end
end
