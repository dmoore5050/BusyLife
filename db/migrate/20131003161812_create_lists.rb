class CreateLists < ActiveRecord::Migration
  def change
    create_table :lists do |t|
      t.string     :name, :guid
      t.text       :contents
      t.references :board
      t.string     :webhook
      t.timestamps
    end
    add_index :lists, :guid, :unique => true
  end
end
