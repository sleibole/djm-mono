class MagicLinksController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create,
             by: -> { params[:email].to_s.downcase.strip },
             with: -> { redirect_to login_path, notice: "Check your email for a login link." }
  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to login_path, notice: "Check your email for a login link." }

  def create
    email = User.normalize_value_for(:email, params[:email])
    user = User.find_by(email: email)
    new_user = false

    if user.nil?
      role = %w[dj audience].include?(params[:role]) ? params[:role] : "audience"
      user = User.create!(email: email, role: role)
      new_user = true
    end

    _magic_token, raw_token = MagicToken.generate_for(user)
    AuthMailer.magic_link(user, raw_token).deliver_later

    if new_user
      redirect_to signup_path, notice: "Welcome! Check your email to get started."
    else
      redirect_to login_path, notice: "Welcome back! Check your email to sign in."
    end
  end

  # GET — read-only landing page that auto-submits to `redeem` via POST.
  # No state mutation here (LiteFS: GETs may hit read replicas).
  def show
    @token = params[:token]
    magic_token = MagicToken.find_by_raw_token(@token)

    if magic_token.nil? || !magic_token.valid_token?
      redirect_to login_path, alert: "This link has expired or already been used. Please request a new one."
    end
  end

  # POST — all state mutation happens here, guaranteed to hit the primary.
  def redeem
    magic_token = MagicToken.find_by_raw_token(params[:token])

    if magic_token.nil? || !magic_token.valid_token?
      redirect_to login_path, alert: "This link has expired or already been used. Please request a new one."
      return
    end

    magic_token.consume!
    user = magic_token.user
    user.confirm_email!
    log_in(user)

    redirect_to root_path, notice: "You're signed in!"
  end
end
