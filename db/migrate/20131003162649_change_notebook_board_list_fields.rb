class ChangeNotebookBoardListFields < ActiveRecord::Migration
  def change
    connection.execute(%q{
      alter table notebook_boards
      alter column list_id
      type integer using cast(list_id as integer)
    })

    rename_column :notebook_boards, :compiledupdatetimes, :compiled_update_times
    remove_column :notebook_boards, :list_name
  end
end
