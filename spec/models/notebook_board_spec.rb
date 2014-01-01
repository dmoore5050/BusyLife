require 'spec_helper'

describe NotebookBoard, 'columns' do
  it { should have_db_column :notebook_id }
  it { should have_db_column :board_id }
  it { should have_db_column :list_id }
  it { should have_db_column :user_id }
  it { should have_db_column :compiled_update_times }
  it { should have_db_column :share_flag }
end

describe NotebookBoard, 'validations' do
  it {should validate_presence_of(:notebook_id) }
  it {should validate_presence_of(:board_id) }
  it {should validate_presence_of(:user_id) }
end

describe NotebookBoard, 'associations' do
  it { should belong_to :notebook }
  it { should belong_to :board }
  it { should belong_to :user }
  it { should belong_to :list}
end

describe NotebookBoard, '#set_attrs' do
  it 'should add share_flag and list_id to notebook_board record' do
    nbb = NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1)
    nbb.set_attrs true, 1
    nbb.list_id.should eq 1
    nbb.share_flag.should eq true
  end

  it 'should change list_id and list_name if they already exits' do
    nbb = NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1, list_id: 1, share_flag: false)
    nbb.list_id.should eq 1
    nbb.share_flag.should eq false

    nbb.set_attrs true, 3
    nbb.list_id.should eq 3
    nbb.share_flag.should eq true
  end
end

describe NotebookBoard, '#set_compiled_update_times' do
  it 'should add compiled_update_times to notebook_board record' do
    nbb = NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1)
    new_list = 'new list'
    nbb.set_compiled_update_times new_list
    nbb.compiled_update_times.should eq 'new list'
  end

  it 'should change compiled_update_times if already present in record' do
    nbb = NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1, compiled_update_times: 'original list')
    nbb.compiled_update_times.should eq 'original list'

    new_list = 'new list'
    nbb.set_compiled_update_times new_list
    nbb.compiled_update_times.should eq 'new list'
  end
end

describe NotebookBoard, '.validate_records' do
  it 'should delete any records with no list_id' do
    NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1)
    notebooks_no_list = NotebookBoard.where(list_id: nil).all
    notebooks_no_list.length.should eq 1
    NotebookBoard.validate_records
    new_list = NotebookBoard.where(list_id: nil).all
    new_list.length.should eq 0
  end

  it 'should not delete any records with a list_id' do
    NotebookBoard.create(notebook_id: 1, board_id: 1, user_id: 1, list_id: 6)
    notebooks_no_list = NotebookBoard.all
    notebooks_no_list.length.should eq 1
    NotebookBoard.validate_records
    new_list = NotebookBoard.all
    new_list.length.should eq 1
  end
end
