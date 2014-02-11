class AuthenticationsController < ApplicationController
  def index
    redirect_to new_synchronization_url if current_user
  end

  def evernote
    oauth_handle request.env['omniauth.auth']
  end

  def trello
    oauth_handle request.env['omniauth.auth']
  end

  def passthru
    render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
  end

  def failure
  end

  def reauthenticate
    @provider = params[:provider]
  end

  private

  def oauth_handle omni
    authentication = Authentication.find_or_create_for_oauth(omni, current_user)
    if authentication.persisted?
      flash[:notice] = "Logged in Successfully"
      current_user = User.find(authentication.user_id)
      set_cookie(current_user.authentications)
      sign_in current_user
      redirect_to current_user.redirect_path
    elsif current_user
      current_user.update_token(omni)
      set_cookie(current_user.authentications)
      flash[:notice] = "Authentication successful."
      sign_in current_user
      redirect_to current_user.redirect_path
    end
  end

  def set_cookie authentications
    cookies.signed[:bl_signed] = { value: Authentication.create_cookie_string(authentications), :expires => 90.days.from_now }
  end
end
