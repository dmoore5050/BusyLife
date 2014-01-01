require 'spec_helper'

describe List, 'instance' do
  let!(:user)          { FactoryGirl.create :user }
  let!(:board)         { FactoryGirl.create :board, user: user }
  let!(:guid)          { '51d6d0ca27a305fa5300590c' }
  let!(:name)          { 'List Name' }
  let!(:trello_auth)   { FactoryGirl.create :trello_auth }
  let!(:trello_client) { TrelloClient.new trello_auth }

  describe List, 'columns' do
    it { should have_db_column :name }
    it { should have_db_column :guid }
    it { should have_db_column :contents }
    it { should have_db_column :board_id }
    it { should have_db_column :webhook }
  end

  describe List, 'validations' do
    it { should validate_uniqueness_of :guid }
    it { should validate_presence_of :guid }
    it { should validate_presence_of :name }
    it { should validate_presence_of :board_id }
  end

  describe List, 'associations' do
    it { should have_many :notebook_boards }
    it { should belong_to :board }
  end

  describe List, '.populate_list' do

    subject do
      VCR.use_cassette('List populate_list') do
        the_list  = List.create( guid: guid, name: name, board_id: board.id )
        List.populate_list the_list, trello_client
      end
    end

    it { should be_a_kind_of List }
    its(:guid)     { should eq guid }
    its(:name)     { should eq name }
    its(:board_id) { should eq board.id }
    its(:contents) { should be_a_kind_of String }
    its(:contents) { should include "{\"content\"=>\"name\", \"guid\"=>\"5293aba0d70e12104100515e\"}" }
  end

  describe List, '#set_content_string' do
    let!(:list) { FactoryGirl.create :list, board: board }

    it 'should start with a list where contents field is populated' do
      list.contents.should eq "[{\"content\"=>\"name\", \"guid\"=>\"guid\"}]"
    end

    subject do
      VCR.use_cassette('List create_populated_list') do
        list.set_content_string trello_client
        list.contents
      end
    end

    it { should be_a_kind_of String }
    it { should include "{\"content\"=>\"Write initial integration tests\", \"guid\"=>\"51d6d149d76b67b553005c7b\"}" }
  end

  describe List, '.set_webhook_attr' do
    let!(:webhook_id) { 'abcde12345' }
    let!(:list)       { FactoryGirl.create :list, board: board }

    it 'should start with a list where webhook field is nil' do
      list.webhook.should eq nil
    end

    subject do
      List.set_webhook_attr list, webhook_id
      list.webhook
    end

    it { should be_a_kind_of String }
    it { should eq webhook_id }
  end

  describe List, '.set_list' do
    it "should create a new List if guid doesn't match" do
      list =  List.set_list guid, name, board
      list.guid.should eq guid
      list.name.should eq name
      list.board_id.should eq board.id
    end

    it 'should use existing List if guid matches' do
      List.create(guid: guid, name: 'test list', board_id: 999)
      list = List.set_list guid, name, board
      list.name.should eq 'test list'
      list.guid.should eq guid
      list.board_id.should eq 999
    end
  end

  describe List, '.find_list_by_guid' do
    it 'should find a list if given guid' do
      List.create(guid: guid, name: name, board_id: board.id)
      list = List.find_list_by_guid guid
      list.should be_a_kind_of List
      list.guid.should eq guid
      list.name.should eq name
      list.board_id.should eq board.id
    end

    it 'should return nil if given invalid guid' do
      guid = '1'
      list = List.find_list_by_guid guid
      list.should eq nil
    end
  end

  describe List, '#still_in_use?' do
    it 'should return true if a board uses given list' do
      list = List.create guid: '12345abcd', name: 'something', board_id: 2
      (1..2).each { |n| NotebookBoard.create notebook_id: 1, board_id: board.id, user_id: user.id, list_id: list.id }
      list.still_in_use?.should eq true
    end

    it 'should return false if no board is using given list' do
      list = List.create guid: '12345abcd', name: 'something', board_id: 2
      list.still_in_use?.should eq false
    end
  end

end