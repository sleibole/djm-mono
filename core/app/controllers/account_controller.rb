class AccountController < ApplicationController
  before_action :require_login

  def show
  end

  def update_password
    if params[:password].blank?
      redirect_to account_path, alert: "Password can't be blank."
      return
    end

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      redirect_to account_path, notice: "Password has been set."
    else
      redirect_to account_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def remove_password
    current_user.update_columns(password_digest: nil)
    redirect_to account_path, notice: "Password removed. You'll use magic links to log in."
  end

  def update_slug
    if current_user.update(slug: params[:slug])
      redirect_to account_path, notice: "Handle updated."
    else
      redirect_to account_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def update_display_name
    if current_user.update(display_name: params[:display_name].presence)
      redirect_to account_path, notice: "Display name updated."
    else
      redirect_to account_path, alert: current_user.errors.full_messages.to_sentence
    end
  end
end
