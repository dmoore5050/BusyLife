require 'spec_helper'

describe Authentication do

  before do
    FactoryGirl.reload
  end

  describe "columns" do
    it { should have_db_column(:provider) }
    it { should have_db_column(:uid) }
    it { should have_db_column(:token) }
    it { should have_db_column(:token_secret) }
    it { should have_db_column(:created_at) }
    it { should have_db_column(:updated_at) }
    it { should have_db_column(:user_id) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "#has?" do
    let!(:user) { FactoryGirl.create(:user) }
    let!(:instance) { FactoryGirl.create(:evernote_auth, user_id: user.id) }

    it "should return true if has provider" do
      provider = "evernote"
      instance.has?(provider).should be true
    end

    it "should return false if user does not have provider" do
      provider = "some_provider"
      instance.has?(provider).should be false
    end
  end

  describe ".create_cookie_string" do
    let!(:user) { FactoryGirl.create(:user) }
    let!(:authentication) { FactoryGirl.create(:evernote_auth, user_id: user.id) }
    subject { Authentication.create_cookie_string(user.reload.authentications) }

    it "should create a string with first character of provider followed by uid" do
      subject.should == ["evernote:472622"].to_json
    end
  end

end
