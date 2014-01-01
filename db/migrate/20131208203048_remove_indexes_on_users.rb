class RemoveIndexesOnUsers < ActiveRecord::Migration
  def down
    remove_index :users, :name => 'index_users_on_email'
    remove_index :users, :name => 'index_users_on_authentication_token'
  end
end
