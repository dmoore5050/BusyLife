require 'spec_helper'

describe SynchronizationsController do
  include Devise::TestHelpers

  let!(:user)          { FactoryGirl.create :user }
  let!(:evernote_auth) { FactoryGirl.create :evernote_auth }
  let!(:trello_auth)   { FactoryGirl.create :trello_auth }
  let!(:board)         { FactoryGirl.create :board, user: user }
  let!(:board2)        { FactoryGirl.create :board2, user: user }
  let!(:board3)        { FactoryGirl.create :board3, user: user }
  let!(:notebook)      { FactoryGirl.create :notebook, user: user }
  let!(:notebook2)     { FactoryGirl.create :notebook2, user: user }
  let!(:notebook3)     { FactoryGirl.create :notebook3, user: user }
  let!(:notebook4)     { FactoryGirl.create :notebook4, user: user }
  let!(:list)          { FactoryGirl.create :list, board: board }
  let!(:list2)         { FactoryGirl.create :list2, board: board }
  let!(:nbb)           { FactoryGirl.create :notebook_board, board: board, notebook: notebook, user: user, list: list }
  let!(:nbb2)          { FactoryGirl.create :notebook_board, board: board, notebook: notebook4, user: user, list: list}

  before do sign_in user end

  subject do
    @controller = SynchronizationsController.new
    @controller.stub(:current_user).and_return user
    @controller
  end

  describe '#new' do
    it 'should render the new view' do
      VCR.use_cassette('new') do
        get :new
        response.should render_template :new
      end
    end
  end

  describe '#create' do
    it 'should redirect to synchronizations/new if provided existing board' do
      VCR.use_cassette('create') do
        post :create, notebook_board: { list_id: { '0' => "#{list2.guid}|#{list2.name}|#{nbb2.id}|#{notebook4.guid}" } }
        response.should redirect_to new_synchronization_url
      end
    end

    it 'should redirect to synchronizations/new if asked to create new board' do
      VCR.use_cassette('create_blank_params') do
        post :create, notebook_board: { list_id: { '0' => '' } }, new_list_params: { '0' => "#{notebook4.name}|#{board.guid}|#{nbb2.id}|#{notebook4.guid}" }
        response.should redirect_to new_synchronization_url
      end
    end
  end

  describe '#prepare' do
    it 'should assign instance vars' do
      VCR.use_cassette('lists') do
        post :prepare, notebook_board: { notebook_id: ["864bb4a6-fa60-4ec8-99b5-77b7fec96930|notebook_name", "" ], board_id: "51d6d0ca27a305fa5300590a|board_name" }
        assigns(:nbbs).should_not be_nil
        assigns(:board_match).should_not be_nil
        assigns(:notebook_set).should_not be_nil
      end
    end

    it 'should render map view on completion' do
      VCR.use_cassette('lists') do
        post :prepare, notebook_board: { notebook_id: ["#{notebook2.guid}|notebook_name", "" ], board_id: "#{board.guid}|board_name" }
        response.should redirect_to "/synchronizations/map?board=#{board.id}&notebook_boards=#{NotebookBoard.last.id}&notebooks=#{notebook2.id}"
      end
    end
  end

  describe '#update' do
    it 'should redirect to synchronizations.new if given a single notebook_id' do
      VCR.use_cassette('update') do
        put :update, id: nbb, notebook_board: { id: board.id, notebook_id: ["#{notebook3.guid}|Title sync|#{list.id}|#{list.guid}", ""] }
        response.should redirect_to new_synchronization_url
      end
    end

    it 'should redirect to synchronizations.new if given multiple notebook_ids' do
      VCR.use_cassette('update_multiple_ids') do
        put :update, id: nbb, notebook_board: { id: board.id, notebook_id: ["#{notebook3.guid}|Title sync|#{list.id}|#{list.guid}", "#{notebook4.guid}|Not title sync|#{list.id}|#{list.guid}"] }
        response.should redirect_to new_synchronization_url
      end
    end
  end

  describe '#destroy' do
    it 'should redirect to synchronizations.new' do
      delete :destroy, id: nbb, notebook_board: { notebook: "#{notebook.guid}|#{list.id}" }
      response.should redirect_to new_synchronization_url anchor: 'synchronizations_wrapper'
    end
  end

  describe '#evernote_listener' do
    let!(:note_guid) { '03adc9f2-5564-44cc-9b77-6859ea5f91eb' }

    it 'should respond OK to external GET request with reason: update' do
      VCR.use_cassette('evernote_listener_update') do
        get :evernote_listener, userId: evernote_auth.uid, guid: note_guid, notebookGuid: notebook4.guid, reason: 'update'
        response.should be_success
        response.body.should be_blank
      end
    end

    it 'should respond OK to external GET request with reason: create' do
      VCR.use_cassette('evernote_listener_create') do
        get :evernote_listener, userId: evernote_auth.uid, guid: note_guid, notebookGuid: notebook4.guid, reason: 'create'
        response.should be_success
        response.body.should be_blank
      end
    end
  end

  describe '#trello_listener' do
    it 'should respond OK to external GET request with no synch params' do
      get :trello_listener, user_id: user.id, list_id: list.id
      response.should be_success
      response.body.should be_blank
    end

    it 'should respond OK to external POST request with archived card' do
      VCR.use_cassette('trello_listener_remove_card') do
        trello_auth.destroy
        new_list = List.create( guid: "52b609e1996e8ebd5000325d", name: 'Title sync', board_id: board2.id )
        new_list_b = List.create( guid: "5298f71b6146fa1b050083f0", name: 'Basics', board_id: board3.id, contents: [{ 'content' => 'content' }].inspect )
        auth = FactoryGirl.create :trello_auth, uid: "5298f71b6146fa1b050083ea", token: "ed2b32908df46be87e38c75f37c948aee71067bd4ebe434125326c354aca0d04", token_secret: "b6b6bd9de4852e5c3ecd58b0712b3883"
        trello_client = TrelloClient.new auth
        new_list.set_content_string trello_client
        trello_client.update_list
        new_nbb = FactoryGirl.create :notebook_board, board: board2, notebook: notebook, user: user, list: new_list
        new_nbb_b = FactoryGirl.create :notebook_board, board: board3, notebook: notebook, user: user, list: new_list_b

        post :trello_listener, user_id: user.id, list_id: new_list.id, model: { closed: false }, synchronization: { action: { id: '123', data: { card: { name: 'Content 1', id: '52b609e25d5927f00a00a4de' } } } }
        response.should be_success
        response.body.should be_blank
      end
    end

    it 'should respond OK to external POST request with closed list params' do
      VCR.use_cassette('trello_listener_closed_list') do
        post :trello_listener, user_id: user.id, list_id: list.id, model: { closed: true }, synchronization: { action: { id: '123', type: '', data: {} } }
        response.should be_success
        response.body.should be_blank
      end
    end
  end

  describe '#trello_client' do
    it 'should set the trello_client' do
      subject.send('trello_client').user_auth.should eq trello_auth
    end
  end

  describe '#evernote_client' do
    it 'should set the evernote client' do
      subject.send('evernote_client').user_auth.should eq evernote_auth
    end
  end

  describe '#synchronizer' do
    it 'should create an instance of synchronizer' do
      subject.send('synchronizer').should be_a_kind_of Synchronizer
    end
  end

  describe '#board_list' do
    it 'should return an array of 9 boards' do
      VCR.use_cassette('board_list') do
        board_array = subject.send 'board_list'
        board_array.length.should eq 9
        board_array.first.class.should eq Trello::Board
      end
    end
  end

  describe '#notebook_list' do
    it 'should return an array of 2 notebooks' do
      VCR.use_cassette('notebook_list') do
        notebook_array = subject.send 'notebook_list'
        notebook_array.length.should eq 2
        notebook_array.first.class.should eq Evernote::EDAM::Type::Notebook
      end
    end
  end

  describe '#notebook' do
    it 'should create a new instance of Notebook' do
      expected = subject.send 'notebook'
      expected.class.should eq Notebook
    end
  end

  describe 'paramify' do
    it 'should convert a list of models to an id string' do
      array = [board, board2, board3]
      ids = subject.send 'paramify', array
      ids.should eq "#{board.id},#{board2.id},#{board3.id}"
    end
  end

  describe 'unparamify' do
    it 'should convert an id string into a list of models' do
      ids = "#{board.id},#{board2.id},#{board3.id}"
      array = subject.send 'unparamify', ids, Board
      array.should eq [board, board2, board3]
    end
  end

  describe '#notebook_boards' do
    before(:each) do
      5.times { |i| FactoryGirl.create(:notebook_board, board_id: i+1, notebook_id: i+1, user_id: user.id ) }
    end

    it 'should return an array of 6 records' do
      expected = subject.send 'notebook_boards'
      expected.class.should eq Array
      expected.length.should eq 6
      expected.first.class.should eq NotebookBoard
    end
  end

  describe '#find_notebook_guids' do
    it 'should return string(s) containing guid and name given notebook id' do
      notebook = Notebook.create guid: 'the_guid', name: 'notebook name', user_id: user.id
      NotebookBoard.create notebook_id: notebook.id, board_id: board.id, list_id: list.id, user_id: user.id
      subject.send(:find_notebook_guids, board.id)[1].should include "c9e72153-5dff-475f-bbea-7b8ab18f6a00|dmoore5050's notebook|#{list.id}"
    end
  end

  describe '#get_board_name' do
    it 'should return name of board given id' do
      board = Board.create name: 'the_name', user_id: user.id
      subject.send(:get_board_name, board.id).should eq 'the_name'
    end
  end

end