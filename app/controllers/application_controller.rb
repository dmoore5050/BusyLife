class ApplicationController < ActionController::Base
  protect_from_forgery

  def after_sign_in_path_for(user)
    user.redirect_path
  end

end
