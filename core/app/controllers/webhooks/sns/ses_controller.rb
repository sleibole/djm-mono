# frozen_string_literal: true

require "net/http"

module Webhooks
  module Sns
    class SesController < ActionController::Base
      skip_forgery_protection

      before_action :verify_sns_payload

      def create
        case sns_params["Type"]
        when "SubscriptionConfirmation"
          confirm_subscription
        when "Notification"
          process_notification
        else
          Rails.logger.info("[SES SNS] Ignored unknown message type: #{sns_params["Type"]}")
          head :no_content
        end
      end

      private

      def confirm_subscription
        subscribe_url = sns_params["SubscribeURL"]

        if subscribe_url.blank?
          Rails.logger.warn("[SES SNS] SubscriptionConfirmation missing SubscribeURL")
          head :bad_request
          return
        end

        uri = URI(subscribe_url)
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.info("[SES SNS] Subscription confirmed for topic #{sns_params["TopicArn"]}")
          head :ok
        else
          Rails.logger.error("[SES SNS] Subscription confirmation failed: HTTP #{response.code}")
          head :bad_gateway
        end
      rescue StandardError => e
        Rails.logger.error("[SES SNS] Subscription confirmation error: #{e.class} - #{e.message}")
        head :bad_gateway
      end

      def process_notification
        SesSnsEventProcessor.call(sns_params["Message"])
        head :ok
      end

      def sns_params
        @sns_params ||= JSON.parse(request.raw_post)
      rescue JSON::ParserError => e
        Rails.logger.warn("[SES SNS] Malformed JSON: #{e.message}")
        nil
      end

      def verify_sns_payload
        unless request.content_type&.include?("json") || request.content_type&.include?("text/plain")
          Rails.logger.warn("[SES SNS] Rejected non-JSON Content-Type: #{request.content_type}")
          head :bad_request
          return
        end

        if sns_params.nil?
          head :bad_request
          return
        end

        missing = %w[Type TopicArn Message] - sns_params.keys
        if missing.any?
          Rails.logger.warn("[SES SNS] Missing required fields: #{missing.join(", ")}")
          head :bad_request
        end
      end
    end
  end
end
