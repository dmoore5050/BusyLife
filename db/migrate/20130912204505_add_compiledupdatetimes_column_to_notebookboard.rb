class AddCompiledupdatetimesColumnToNotebookboard < ActiveRecord::Migration
  def change
    add_column :notebook_boards, :compiledupdatetimes, :text
  end
end
