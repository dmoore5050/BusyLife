require 'spec_helper'

describe TrelloClient, 'instance' do
  let!(:user)          { FactoryGirl.create :user }
  let!(:evernote_auth) { FactoryGirl.create :evernote_auth }
  let!(:trello_auth)   { FactoryGirl.create :trello_auth }
  let!(:trello_client) { TrelloClient.new trello_auth }

  subject do trello_client end

  before :each do subject.stub(:current_user).and_return user end

  it { should be_an_instance_of TrelloClient }
  its(:current_user) { should eq user }

  describe TrelloClient, '#initialize' do
    its(:user_auth) { should eq trello_auth }
    its(:client)    { should be_a_kind_of Trello::Client }
  end

  describe TrelloClient, '#client' do
    subject do trello_client.client end

    its(:oauth_token)        { should eq trello_auth.token }
    its(:oauth_token_secret) { should eq trello_auth.token_secret }
    its(:consumer_key)       { should eq AppConfig['trello_key'] }
    its(:consumer_secret)    { should eq AppConfig['trello_secret'] }
  end

  describe TrelloClient, '#boards' do
    subject do
      VCR.use_cassette('trello client boards') do
        trello_client.boards
      end
    end

    it { should be_a_kind_of Array }
    its(:first)  { should be_a_kind_of Trello::Board }
    its(:length) { should eq 10 }
  end

  describe TrelloClient, '#lists' do
    let!(:board_guid)    { '521248f3819c6e447f009cc2' }

    subject do
      VCR.use_cassette('trello client lists') do
        trello_client.lists board_guid
      end
    end

    it { should be_a_kind_of Array }
    its(:first)  { should be_a_kind_of Hash }
    its(:first)  { should have_key :name }
    its(:first)  { should have_value 'To Do' }
    its(:length) { should eq 3 }
  end

  describe TrelloClient, '#create_list' do
  end

  describe TrelloClient, '#get_raw_cards' do
  end

  describe TrelloClient, '#cards' do
    let!(:board) { FactoryGirl.create :board, user: user}
    let!(:list)  { FactoryGirl.create :list, board: board }

    subject do
      VCR.use_cassette('trello client cards') do
        trello_client.cards list
      end
    end

    it { should be_a_kind_of Array }
    its(:first)     { should be_a_kind_of Hash }
    its(:first)     { should have_key 'content' }
    its(:first)     { should have_value 'Write initial integration tests' }
    its(:length)    { should eq 54 }
  end

  describe TrelloClient, '#remove_outdated_cards' do
  end

  describe TrelloClient, '#create_content_string' do
  end

  describe TrelloClient, '#delete_card' do
  end

  describe TrelloClient, '#sync_trello' do
  end

  describe TrelloClient, '#build_single_card' do
  end

  describe TrelloClient, '#create_card' do
  end

  describe TrelloClient, '#build_card_description' do
    let!(:evernote_client) { EvernoteClient.new evernote_auth }
    let!(:guid)            { '123456abcdefg' }
    let!(:note)            { { 'content' => 'sample content', 'guid' => '03adc9f2-5564-44cc-9b77-6859ea5f91eb' } }
    let!(:share_url) do
      VCR.use_cassette('trello client share_single_note') do
        evernote_client.share_single_note note['guid']
      end
    end

    subject do
      VCR.use_cassette('trello client description') do
        client = trello_client.build_card_description evernote_client, note, guid, share_flag
      end
    end

    context 'share_flag is true' do
      let!(:share_flag) { true }

      it { should be_a_kind_of String }
      it { should include guid }
      it { should include note['guid'] }
      it { should include share_url }
    end

    context 'share_flag is false' do
      let!(:share_flag) { false }

      it { should be_a_kind_of String }
      it { should include guid }
      it { should include note['guid'] }
      it { should_not include share_url }
    end
  end
end