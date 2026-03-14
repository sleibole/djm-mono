# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class TurnstileVerificationService
  SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze
  TIMEOUT_SECONDS = 5

  def self.call(token, remote_ip: nil)
    new.call(token, remote_ip: remote_ip)
  end

  def initialize
    @secret_key = ENV["TURNSTILE_SECRET_KEY"]
  end

  def call(token, remote_ip: nil)
    return error_response("Token is missing") if token.blank?
    return error_response("Secret key is not configured") if @secret_key.blank?

    begin
      response = verify_with_cloudflare(token, remote_ip)
      parse_response(response)
    rescue Net::ReadTimeout, Net::OpenTimeout, Timeout::Error
      error_response("Request to Cloudflare timed out")
    rescue StandardError => e
      Rails.logger.error("[TurnstileVerificationService] Error: #{e.class} - #{e.message}")
      error_response("Verification request failed: #{e.message}")
    end
  end

  private

  def verify_with_cloudflare(token, remote_ip)
    uri = URI(SITEVERIFY_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT_SECONDS
    http.open_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri.path)

    form_data = {
      "secret" => @secret_key,
      "response" => token
    }
    form_data["remoteip"] = remote_ip if remote_ip.present?

    request.set_form_data(form_data)
    http.request(request)
  end

  def parse_response(response)
    if response.code != "200"
      return error_response("Cloudflare API returned status #{response.code}")
    end

    body = JSON.parse(response.body)
    success = body["success"] == true

    if success
      { success: true, challenge_ts: body["challenge_ts"], hostname: body["hostname"], error_codes: [] }
    else
      { success: false, error_codes: body["error-codes"] || [], challenge_ts: body["challenge_ts"], hostname: body["hostname"] }
    end
  rescue JSON::ParserError => e
    error_response("Invalid JSON response from Cloudflare: #{e.message}")
  end

  def error_response(message)
    { success: false, error_codes: ["internal_error"], error_message: message }
  end
end
