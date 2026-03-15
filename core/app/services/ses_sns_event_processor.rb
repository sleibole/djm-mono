# frozen_string_literal: true

class SesSnsEventProcessor
  def self.call(message_json)
    new(message_json).process
  end

  def initialize(message_json)
    @event = JSON.parse(message_json)
  rescue JSON::ParserError => e
    Rails.logger.warn("[SES Event] Malformed event JSON: #{e.message}")
    @event = nil
  end

  def process
    return if @event.nil?

    type = @event["notificationType"]
    message_id = @event.dig("mail", "messageId")

    case type
    when "Delivery"
      handle_delivery(message_id)
    when "Bounce"
      handle_bounce(message_id)
    when "Complaint"
      handle_complaint(message_id)
    else
      Rails.logger.info("[SES Event] Ignored unknown type=#{type} message_id=#{message_id}")
    end
  end

  private

  def handle_delivery(message_id)
    emails = @event.dig("mail", "destination") || []
    timestamp = parse_timestamp(@event.dig("delivery", "timestamp"))

    users = User.where(email: emails)
    users.update_all(last_delivered_at: timestamp || Time.current)

    Rails.logger.info(
      "[SES Event] type=Delivery message_id=#{message_id} emails=#{emails.join(",")} updated=#{users.length}"
    )
  end

  def handle_bounce(message_id)
    bounce = @event["bounce"] || {}
    recipients = bounce["bouncedRecipients"] || []
    emails = recipients.map { |r| r["emailAddress"] }.compact
    timestamp = parse_timestamp(bounce["timestamp"])
    bounce_type = bounce["bounceType"]
    bounce_subtype = bounce["bounceSubType"]
    reason = [ bounce_type, bounce_subtype ].compact.join(" / ")

    users = User.where(email: emails)
    users.update_all(
      email_status: "bounced",
      email_status_reason: reason,
      last_bounced_at: timestamp || Time.current
    )

    Rails.logger.info(
      "[SES Event] type=Bounce message_id=#{message_id} bounce_type=#{bounce_type} " \
      "emails=#{emails.join(",")} updated=#{users.length}"
    )
  end

  def handle_complaint(message_id)
    complaint = @event["complaint"] || {}
    recipients = complaint["complainedRecipients"] || []
    emails = recipients.map { |r| r["emailAddress"] }.compact
    timestamp = parse_timestamp(complaint["timestamp"])
    feedback_type = complaint["complaintFeedbackType"]

    users = User.where(email: emails)
    users.update_all(
      email_status: "complained",
      email_status_reason: feedback_type,
      last_complained_at: timestamp || Time.current
    )

    Rails.logger.info(
      "[SES Event] type=Complaint message_id=#{message_id} feedback=#{feedback_type} " \
      "emails=#{emails.join(",")} updated=#{users.length}"
    )
  end

  def parse_timestamp(value)
    Time.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
