module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "Please log in to continue."
    end
  end

  def require_admin
    require_login
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end

  def log_in(user)
    reset_session
    session[:user_id] = user.id
    user.reset_failed_logins!
  end

  def log_out
    reset_session
    @current_user = nil
  end
end
