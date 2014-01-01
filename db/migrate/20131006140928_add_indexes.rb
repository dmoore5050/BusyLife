class AddIndexes < ActiveRecord::Migration
  def change
    add_index :notebook_boards, :board_id
    add_index :notebook_boards, :notebook_id
    add_index :notebook_boards, :user_id
    add_index :notebooks, :guid
    add_index :boards, :guid
  end
end
