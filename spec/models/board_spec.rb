require 'spec_helper'

describe Board, 'columns' do
  it { should have_db_column :name }
  it { should have_db_column :description }
  it { should have_db_column :guid }
  it { should have_db_column :url }
  it { should have_db_column :organization_id }
  it { should have_db_column :user_id }
end

describe Board, 'validations' do
  it { should validate_uniqueness_of :guid }
  it { should validate_presence_of :user_id }
end

describe Board, 'associations' do
  it { should belong_to :user }
  it { should have_many :notebook_boards }
  it { should have_many(:notebooks).through :notebook_boards }
end

describe Board, '.set_board' do
  it "should create a new Board if guid doesn't match" do
    params, user_id = '1|trelloName', 1
    board = Board.set_board params, user_id
    board.name.should eq'trelloName'
  end

  it 'should use existing Board if guid matches' do
    Board.create(guid: '1', name: 'test board', user_id: 1)
    params, user_id = '1|trelloName', 1
    board = Board.set_board params, user_id
    board.name.should eq 'test board'
  end
end

describe Board, '.find_board_by_guid' do

  it 'should find a board if given guid' do
    Board.create(guid: '1', name: 'test board', user_id: 1)
    guid = '1'
    board = Board.find_board_by_guid guid
    board.name.should eq 'test board'
  end

  it 'should return nil if given invalid guid' do
    guid = '1'
    board = Board.find_board_by_guid guid
    board.should eq nil
  end

end