module SessionManagement
  def login_as_user user = nil
    user ||= FactoryGirl.create(:user)
    login_as(user)  # login_as is defined in Warden::Test::Helpers
    user
  end
end

RSpec.configure do |config|
  config.include Warden::Test::Helpers, :type => :request
  config.after(:each, :type => :request) { Warden.test_reset! }

  config.include SessionManagement, :type => :request
end