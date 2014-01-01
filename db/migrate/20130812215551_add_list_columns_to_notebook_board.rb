class AddListColumnsToNotebookBoard < ActiveRecord::Migration
  def change
    add_column :notebook_boards, :list_name, :string
    add_column :notebook_boards, :list_id, :string
  end
end
