require 'spec_helper'

describe EvernoteClient, 'instance' do
  let!(:user)            { FactoryGirl.create :user }
  let!(:evernote_auth)   { FactoryGirl.create :evernote_auth }
  let!(:evernote_client) { EvernoteClient.new evernote_auth }
  let!(:notebook)        { FactoryGirl.create :notebook, user: user }

  before do
    evernote_client.stub(:current_user).and_return(user)
  end

  specify { evernote_client.should be_an_instance_of EvernoteClient }
  specify { evernote_client.current_user.should eq user }

  describe EvernoteClient, '#initialize' do
    specify { evernote_client.user_auth.should eq evernote_auth }
    specify { evernote_client.client.should be_a_kind_of EvernoteOAuth::Client }
  end

  describe EvernoteClient, '#client' do
    let!(:the_client) { evernote_client.client }

    it 'should set evernote auth token' do
      the_client.instance_variable_get(:@token).should eq evernote_auth.token
    end

    it 'should set config keys' do
      the_client.instance_variable_get(:@consumer_key).should eq AppConfig['evernote_key']
      the_client.instance_variable_get(:@consumer_secret).should eq AppConfig['evernote_secret']
    end

    it 'should set sandbox and service host' do
      the_client.instance_variable_get(:@sandbox).should eq AppConfig['evernote_sandbox']
      the_client.instance_variable_get(:@service_host).should eq AppConfig['evernote_api_url']
    end
  end

  describe EvernoteClient, '#user_store' do
    it 'should return Evernote user_store' do
      VCR.use_cassette('evernote client user store') do
        evernote_client.user_store.should be_a_kind_of EvernoteOAuth::UserStore::Store
      end
    end

    it 'should have same token as client' do
      VCR.use_cassette('evernote client user store') do
        token = evernote_client.client.instance_variable_get(:@token)
        evernote_client.user_store.instance_variable_get(:@token).should eq token
      end
    end
  end

  describe EvernoteClient, '#note_store' do
    it 'should return Evernote user_store' do
      VCR.use_cassette('evernote client note store') do
        evernote_client.note_store.should be_a_kind_of EvernoteOAuth::NoteStore::Store
      end
    end

    it 'should have same token as client' do
      VCR.use_cassette('evernote client note store') do
        token = evernote_client.client.instance_variable_get(:@token)
        evernote_client.note_store.instance_variable_get(:@token).should eq token
      end
    end
  end

  describe EvernoteClient, '#shard_id' do
    subject do
      VCR.use_cassette('evernote client shard') do
        evernote_client.shard_id
      end
    end

    it { should be_a_kind_of String }
    it { should eq 's1' }
  end

  describe EvernoteClient, '#en_user' do
    subject do
      VCR.use_cassette('evernote client en_user') do
        evernote_client.en_user
      end
    end

    it { should be_a_kind_of Evernote::EDAM::Type::User }
    its(:id) { should eq evernote_auth.uid.to_i }
  end

  describe EvernoteClient, '#notebooks' do
    subject do
      VCR.use_cassette('evernote client notebooks') do
        evernote_client.notebooks
      end
    end

    it { should be_a_kind_of Array }
    its(:first) { should be_a_kind_of Evernote::EDAM::Type::Notebook }
  end

  describe EvernoteClient, '#total_note_count' do
    subject do
      VCR.use_cassette('evernote client total_note_count') do
        evernote_client.total_note_count notebook
      end
    end

    it { should be_a_kind_of Fixnum}
    it { should eq 345 }
  end

  describe EvernoteClient, '#get_note' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }
  end

  describe EvernoteClient, '#build_note_array' do
    let!(:note_count)      do
      VCR.use_cassette('evernote client total_note_count') do
        evernote_client.total_note_count notebook
      end
    end

    subject do
      VCR.use_cassette('evernote client get_notes') do
        string = evernote_client.build_note_array notebook
        eval string
      end
    end

    it { should be_a_kind_of Array }
    its(:first)  { should be_a_kind_of Hash }
    its(:first)  { should have_key 'content' }
    its(:first)  { should have_key 'guid' }
    its(:first)  { should have_key 'updated' }
    its(:length) { should eq 54 }
  end

  describe EvernoteClient, '#update_note_array' do                    ####UPDATE
    let!(:update_times)    { "[{\"content\"=>\"Content 1\", \"guid\"=>\"03adc9f2-5564-44cc-9b77-6859ea5f91eb\", \"updated\"=>\"9999999999999\"}, {\"content\"=>\"Content 2\", \"guid\"=>\"39874d8a-a3cf-4b08-a492-ef3647f9837d\", \"updated\"=>\"137916975500\"},{\"content\"=>\"Content 3\", \"guid\"=>\"758be8e4-63f6-4a57-9f7c-8c8af1927905\", \"updated\"=>\"1379169756000\"},{\"content\"=>\"Content 4\", \"guid\"=>\"edd29c5d-f21c-47cf-a1b5-6a546168e517\", \"updated\"=>\"|1379169756000\"},{\"content\"=>\"Content 5\", \"guid\"=>\"848a54c3-13c7-4a13-9107-925fffee46ff\", \"updated\"=>\"1379169757000\"},{\"content\"=>\"Content 6\", \"guid\"=>\"45410c77-9a1e-4ba1-a6b8-84bafcf8056f\", \"updated\"=>\"1379169758000\"}]" }
    let!(:notebook_board)  { NotebookBoard.create(user_id: user.id, board_id: 1, notebook_id: notebook.id, compiled_update_times: update_times)}

    subject do
      VCR.use_cassette('evernote client get_updated_notes') do
        string = evernote_client.update_note_array notebook_board
        eval string
      end
    end

    it { should be_a_kind_of Array }
    its(:length) { should eq 54 }
    its(:first)  { should be_a_kind_of Hash }
    its(:first)  { should have_key 'content' }
    its(:first)  { should have_key 'guid' }
    its(:first)  { should have_key 'updated' }
  end

  describe EvernoteClient, '#modify_comparison_string' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }
  end

  describe EvernoteClient, '#retrieve_raw_notes' do
    context 'retrieves notes from beginning' do
      let!(:offset) { 0 }

      subject do
        VCR.use_cassette('evernote client retrieve_raw_notes no_offset') do
          evernote_client.retrieve_raw_notes offset, notebook
        end
      end

      it { should be_a_kind_of Array }
      its(:first)  { should be_a_kind_of Evernote::EDAM::Type::Note }
      its(:length) { should eq 39 }
    end

    context 'retrieves notes with offset' do
      let!(:offset) { 2 }

      subject do
        VCR.use_cassette('evernote client retrieve_raw_notes offset') do
          evernote_client.retrieve_raw_notes offset, notebook
        end
      end

      its(:length) { should eq 37 }
    end
  end

  describe EvernoteClient, '#new_note_hash' do
    let!(:offset) { 0 }
    let!(:note) do
      VCR.use_cassette('evernote client retrieve_raw_notes no_offset') do
        evernote_client.retrieve_raw_notes(offset, notebook).first
      end
    end

    subject do
      evernote_client.new_note_hash note
    end

    it { should be_a_kind_of Hash }
    it { should have_key 'content' }
    it { should have_key 'guid' }
    it { should have_key 'updated' }
    its(['content']) { should be_a_kind_of String }
    its(['content']) { should eq 'Content 1' }
    its(['guid'])    { should be_a_kind_of String }
    its(['guid'])    { should eq 'ef7d0299-7673-4377-8e17-f01ddf3c63a2' }
    its(['updated']) { should be_a_kind_of String }
    its(['updated']) { should eq '1379951132000' }
  end

  describe EvernoteClient, '#get_unretrieved_notes' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }
    # let!(:notebook_guid)   { 'c9e72153-5dff-475f-bbea-7b8ab18f6a00' }
    # let!(:notes_length)    { 6 }
    # let!(:use_type)        { 'build comp strong' }

    # before :each do FactoryGirl.reload end

    # it 'something' do
    #   VCR.use_cassette('evernote client get_unretrieved_notes') do
    #     instance = evernote_client
    #     instance.build_update_comparison_string notebook_guid
    #     instance.instance_variable_get(:@updated_list)
    #   end
    # end

  end

  describe EvernoteClient, '#filter' do
    let!(:notebook_guid)   { 'df6aabad-7ede-4b44-9936-d64e06c70b21' }

    subject do evernote_client.filter notebook_guid end

    it { should be_a_kind_of Evernote::EDAM::NoteStore::NoteFilter }
    its(:notebookGuid) { should eq notebook_guid }
  end

  describe EvernoteClient, '#share_single_note' do
    let!(:note_guid)       { '1dce557e-644d-4d7d-b13c-5acae9f6db71' }
    let!(:shard_id) do
      VCR.use_cassette('evernote client shard') do
        evernote_client.shard_id
      end
    end

    subject do
      VCR.use_cassette('evernote client share_single_note') do
        evernote_client.share_single_note note_guid
      end
    end

    it { should be_a_kind_of String }
    it { should include 'https://www.evernote.com/shard/' }
    it { should include shard_id }
    it { should include note_guid }
  end

  describe EvernoteClient, '#sync_evernote' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }

    # before :each do FactoryGirl.reload end
  end

  describe EvernoteClient, '#create_note' do
    let!(:note) { { 'content' => 'some content' } }
    let!(:desc) { 'a desc' }

    subject do
      VCR.use_cassette('evernote client create_note') do
        evernote_client.create_note note, notebook, desc
      end
    end

    it { should be_a_kind_of Evernote::EDAM::Type::Note }
    its(:title)        { should eq 'some content' }
    its(:notebookGuid) { should eq notebook.guid }
  end

  describe EvernoteClient, '#delete_note' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }
  end

  describe EvernoteClient, '#invalid' do
    # let!(:evernote_auth)   { FactoryGirl.create(:authentication) }
    # let!(:evernote_client) { EvernoteClient.new evernote_auth }
  end
end