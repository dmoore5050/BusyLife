class AddColumnRawDataToAuthentications < ActiveRecord::Migration
  def change
    add_column :authentications, :source_data, :text
  end
end
