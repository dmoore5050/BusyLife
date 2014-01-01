require 'spec_helper'

describe Synchronizer, 'instance' do
  let!(:user)          { FactoryGirl.create :user }
  let!(:evernote_auth) { FactoryGirl.create :evernote_auth }
  let!(:trello_auth)   { FactoryGirl.create :trello_auth }
  let!(:synchronizer)  { Synchronizer.new trello_auth, evernote_auth }

  subject do synchronizer end

  before do subject.stub(:current_user).and_return user end

  it { should be_an_instance_of Synchronizer }
  its(:current_user) { should eq user }
end