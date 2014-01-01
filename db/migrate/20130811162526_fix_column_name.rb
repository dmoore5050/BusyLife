class FixColumnName < ActiveRecord::Migration

  def self.up
    rename_column :boards, :orginazation_id, :organization_id
  end

end
