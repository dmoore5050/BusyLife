class Authentication < ActiveRecord::Base

  belongs_to :user

  attr_accessible :provider, :uid, :token_secret, :token, :source_data

  def self.find_or_create_for_oauth omni, user = nil
    auth = Authentication.where(:provider => omni.provider, :uid => omni.uid.to_s).first
    unless auth
      name = omni.info.name || omni.info.nickname
      unless user
        user = User.new(
          name:     name,
          email:    omni.info.email || "#{ name }@email.com"
        )
      end
      user.apply_omniauth(omni)
      user.save
      auth = user.authentications.last
    end
    auth
  end

  def has? user_provider
    (provider == user_provider)
  end

  def self.create_cookie_string authentications
    authentications.map{ |a| a.provider + ":" + a.uid }.to_json
  end

end