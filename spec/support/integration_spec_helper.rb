module IntegrationSpecHelper
  def login_with_oauth(service = :evernote)
    visit "/auth/#{service}"
  end
end
