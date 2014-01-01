class CreateBoards < ActiveRecord::Migration
  def change
    create_table :boards do |t|
      t.string :guid, :name, :url, :orginazation_id
      t.text :description
      t.timestamps
    end
  end
end
