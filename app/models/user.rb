class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :trackable, :omniauthable, :omniauth_providers => [:evernote,:trello]

  has_many :authentications
  has_many :notebooks
  has_many :boards
  has_many :notebook_boards

  attr_accessible :email, :password, :password_confirmation, :name

  def apply_omniauth omni
    authentications.build(
                          :provider => omni['provider'],
                          :uid => omni['uid'],
                          :token => omni['credentials'].token,
                          :token_secret => omni['credentials'].secret,
                          :source_data => omni.to_json)
  end

  def update_token omni
    auth = authentications.find_by_provider_and_uid(:provider => omni['provider'], :uid => omni['uid'])
    auth.update_attributes!(:token => omni['credentials'].token, :token_secret => omni['credentials'].secret)
  end

  def redirect_path
    providers = authentications.map(&:provider)

    if providers.include? "evernote" && "trello"
      return '/synchronizations/new'
    elsif providers.include? "evernote"
      return path "trello"
    else
      return path "evernote"
    end
  end

  def path provider
    "/users/auth/#{provider}"
  end

  def evernote
    authentications.find_by_provider(:evernote)
  end

  def trello
    authentications.find_by_provider(:trello)
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end
end
