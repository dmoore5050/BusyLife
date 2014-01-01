class CreateNotebookBoards < ActiveRecord::Migration
  def change
    create_table :notebook_boards do |t|
      t.references :notebook
      t.references :board
      t.references :user
      t.timestamps
    end
  end
end
