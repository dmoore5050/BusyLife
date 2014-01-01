require 'spec_helper'

describe User, "columns" do
  it { should have_db_column(:email) }
  it { should have_db_column(:encrypted_password) }
  it { should have_db_column(:current_sign_in_at) }
  it { should have_db_column(:last_sign_in_at) }
  it { should have_db_column(:current_sign_in_ip) }
  it { should have_db_column(:last_sign_in_ip) }
  it { should have_db_column(:authentication_token) }
  it { should have_db_column(:created_at) }
  it { should have_db_column(:updated_at) }
  it { should have_db_column(:name) }
end

describe User, "associations" do
  it { should have_many(:authentications) }
end

describe User, "#redirect_path" do
  let!(:instance){ FactoryGirl.create(:user) }
  subject { instance.redirect_path }

  it "should return path to omniauth for provider if it doesnt exist" do
    subject.should == "/users/auth/evernote"
  end

  context "If evernote exists" do

    it "should return omniauth path to trello" do
      instance.authentications.create!(provider:"evernote", uid: 123)
      subject.should == "/users/auth/trello"
    end
  end
end
