require 'spec_helper'

describe SynchronizationsController, 'instance' do
  include Devise::TestHelpers

  let!(:user)          { FactoryGirl.create :user }
  let!(:evernote_auth) { FactoryGirl.create :evernote_auth }
  let!(:trello_auth)   { FactoryGirl.create :trello_auth }
  let!(:board)         { FactoryGirl.create :board, user: user }
  let!(:notebook)      { FactoryGirl.create :notebook, user: user }
  let!(:list)          { FactoryGirl.create :list, board: board }
  let!(:nbb)           { FactoryGirl.create :notebook_board, board: board, notebook: notebook, user: user, list: list }

  before do sign_in user end

  subject do
    sync = SynchronizationsController.new
    sync.stub(:current_user).and_return user
    sync
  end

  describe '#new' do
    it 'should render the new view' do
      get :new
      response.should render_template :new
    end
  end

  describe '#edit' do
    it 'should redirect to synchronizations/new if provided existing board' do
      VCR.use_cassette('edit') do
        get :edit, id: nbb, notebook_board: { list_id: { '0' => "51d6d0ca27a305fa5300590c|Doing|#{nbb.id}|df6aabad-7ede-4b44-9936-d64e06c70b21" } }
        response.should redirect_to new_synchronization_url
      end
    end

    it 'should redirect to synchronizations/new if asked to create new board' do
      VCR.use_cassette('edit_blank_params') do
        get :edit, id: nbb, notebook_board: { list_id: { '0' => '' } }, new_list_params: { '0' => "Notebook Name|#{board.guid}|#{nbb.id}|df6aabad-7ede-4b44-9936-d64e06c70b21" }
        response.should redirect_to new_synchronization_url
      end
    end
  end

  describe '#create' do
    it 'should assign instance vars' do
      VCR.use_cassette('lists') do
        post :create, notebook_board: { notebook_id: ["864bb4a6-fa60-4ec8-99b5-77b7fec96930|notebook_name", "" ], board_id: "51d6d0ca27a305fa5300590a|board_name" }
        assigns(:nbbs).should_not be_nil
        assigns(:board_match).should_not be_nil
        assigns(:notebook_set).should_not be_nil
      end
    end

    it 'should render edit view on completion' do
      VCR.use_cassette('lists') do
        post :create, notebook_board: { notebook_id: ["864bb4a6-fa60-4ec8-99b5-77b7fec96930|notebook_name", "" ], board_id: "51d6d0ca27a305fa5300590a|board_name" }
        response.should redirect_to "/synchronizations/map?board=#{Board.last.id}&notebook_boards=#{NotebookBoard.last.id}&notebooks=#{Notebook.last.id}"
      end
    end
  end

  describe '#update' do
    it 'should redirect to synchronizations.new if given a single notebook_id' do
      VCR.use_cassette('update') do
        put :update, id: nbb, notebook_board: { id: nbb.id, notebook_id: ["df6aabad-7ede-4b44-9936-d64e06c70b21|Title sync", ""] }
        response.should redirect_to new_synchronization_url
      end
    end

    it 'should redirect to synchronizations.new if given multiple notebook_ids' do
      VCR.use_cassette('update_multiple_ids') do
        put :update, id: nbb, notebook_board: { id: nbb.id, notebook_id: ["df6aabad-7ede-4b44-9936-d64e06c70b21|Title sync", "864bb4a6-fa60-4ec8-99b5-77b7fec96930|Not title sync"] }
        response.should redirect_to new_synchronization_url
      end
    end
  end

  describe '#destroy' do
    it 'should redirect to synchronizations.new' do
      delete :destroy, id: nbb, notebook_board: { board: board.id, notebook: "#{notebook.guid}|#{notebook.name}" }
      response.should redirect_to new_synchronization_url anchor: 'synchronizations_wrapper'
    end
  end

  describe '#evernote_listener' do
    let!(:note_guid) { '03adc9f2-5564-44cc-9b77-6859ea5f91eb' }

    it 'should respond OK to external GET request with reason: update' do
      VCR.use_cassette('evernote_listener_update') do
        get :evernote_listener, userId: evernote_auth.uid, guid: note_guid, notebookGuid: notebook.guid, reason: 'update'
        response.should be_success
        response.body.should be_blank
      end
    end

    it 'should respond OK to external GET request with reason: create' do
      VCR.use_cassette('evernote_listener_create') do
        get :evernote_listener, userId: evernote_auth.uid, guid: note_guid, notebookGuid: notebook.guid, reason: 'create'
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
        new_list = List.create( guid: "52b609e1996e8ebd5000325d", name: 'Title sync', board_id: board.id )
        new_list_b = List.create( guid: "5298f71b6146fa1b050083f0", name: 'Basics', board_id: board.id, contents: [{ 'content' => 'content' }].inspect )
        auth = FactoryGirl.create :trello_auth, uid: "5298f71b6146fa1b050083ea", token: "ed2b32908df46be87e38c75f37c948aee71067bd4ebe434125326c354aca0d04", token_secret: "b6b6bd9de4852e5c3ecd58b0712b3883"
        trello_client = TrelloClient.new auth
        new_list.set_content_string trello_client
        trello_client.update_list
        new_nbb = FactoryGirl.create :notebook_board, board: board, notebook: notebook, user: user, list: new_list
        new_nbb_b = FactoryGirl.create :notebook_board, board: board, notebook: notebook, user: user, list: new_list_b

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

  describe '#pingdom_listener' do
    it 'should respond OK to external GET request' do
      get :pingdom_listener
      response.should be_success
      response.body.should be_blank
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
      notebook = Notebook.create guid: 'the_guid', name: 'the_name', user_id: user.id
      NotebookBoard.create notebook_id: notebook.id, board_id: board.id, user_id: user.id
      subject.send(:find_notebook_guids, board.id).should include "the_guid|the_name"
    end
  end

  describe '#get_board_name' do
    it 'should return name of board given id' do
      board = Board.create name: 'the_name', user_id: user.id
      subject.send(:get_board_name, board.id).should eq 'the_name'
    end
  end

end