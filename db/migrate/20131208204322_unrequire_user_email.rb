class UnrequireUserEmail < ActiveRecord::Migration
  def down
    change_column :users, :email, :string, :null => true
  end
end
