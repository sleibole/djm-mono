class SessionsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
  end

  def create_with_password
    user = User.find_by(email: params[:email])

    if user.nil?
      redirect_to login_path, alert: "Invalid email or password."
      return
    end

    if user.locked?
      redirect_to login_path, alert: "Account locked. Use a magic link to sign in and unlock your account."
      return
    end

    if !user.has_password?
      redirect_to login_path, alert: "No password set. Use a magic link to sign in."
      return
    end

    if user.authenticate(params[:password])
      log_in(user)
      redirect_to root_path, notice: "Welcome back!"
    else
      user.record_failed_login!
      redirect_to login_path, alert: "Invalid email or password."
    end
  end

  def destroy
    log_out
    redirect_to login_path, notice: "You have been signed out."
  end
end
