# frozen_string_literal: true

module TurnstileVerification
  extend ActiveSupport::Concern

  private

  def verify_turnstile!
    return true unless turnstile_configured?

    token = params["cf-turnstile-response"] || params[:'cf-turnstile-response']
    result = TurnstileVerificationService.call(token, remote_ip: request.remote_ip)

    unless result[:success]
      log_verification_failure(result)
      handle_verification_failure(result)
      return false
    end

    true
  end

  def turnstile_configured?
    ENV["TURNSTILE_SECRET_KEY"].present?
  end

  def log_verification_failure(result)
    Rails.logger.warn("[TurnstileVerification] Verification failed for IP #{request.remote_ip}")
    Rails.logger.warn("[TurnstileVerification] Error codes: #{result[:error_codes].join(', ')}")
    Rails.logger.warn("[TurnstileVerification] Error message: #{result[:error_message]}") if result[:error_message]
  end

  def handle_verification_failure(result)
    error_message = user_friendly_error_message(result)

    if request.format.html?
      flash.alert = error_message
      redirect_back(fallback_location: root_url)
    else
      render json: { error: error_message }, status: :unprocessable_entity
    end
  end

  def user_friendly_error_message(result)
    if result[:error_message]
      "Verification failed. Please try again."
    elsif result[:error_codes].include?("missing-input-response")
      "Please complete the verification challenge."
    elsif result[:error_codes].include?("timeout-or-duplicate")
      "This verification has expired. Please refresh the page and try again."
    else
      "Verification failed. Please try again."
    end
  end
end
