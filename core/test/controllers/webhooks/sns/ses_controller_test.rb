# frozen_string_literal: true

require "test_helper"

class Webhooks::Sns::SesControllerTest < ActionDispatch::IntegrationTest
  TOPIC_ARN = "arn:aws:sns:us-east-1:123456789012:ses-notifications"

  test "confirms SNS subscription" do
    payload = {
      "Type" => "SubscriptionConfirmation",
      "TopicArn" => TOPIC_ARN,
      "Message" => "You have chosen to subscribe...",
      "SubscribeURL" => "https://sns.us-east-1.amazonaws.com/?Action=ConfirmSubscription&Token=abc123"
    }

    original = Net::HTTP.method(:get_response)
    Net::HTTP.define_singleton_method(:get_response) { |_uri| Net::HTTPOK.new("1.1", "200", "OK") }

    post webhooks_sns_ses_url,
      params: payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
  ensure
    Net::HTTP.define_singleton_method(:get_response, original)
  end

  test "processes delivery notification" do
    user = users(:one)

    post webhooks_sns_ses_url,
      params: sns_notification(delivery_event(user.email)).to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
    user.reload
    assert_not_nil user.last_delivered_at
    assert_equal "active", user.email_status
  end

  test "processes bounce notification" do
    user = users(:one)

    post webhooks_sns_ses_url,
      params: sns_notification(bounce_event(user.email)).to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
    user.reload
    assert_equal "bounced", user.email_status
    assert_equal "Permanent / General", user.email_status_reason
    assert_not_nil user.last_bounced_at
  end

  test "processes complaint notification" do
    user = users(:one)

    post webhooks_sns_ses_url,
      params: sns_notification(complaint_event(user.email)).to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
    user.reload
    assert_equal "complained", user.email_status
    assert_equal "abuse", user.email_status_reason
    assert_not_nil user.last_complained_at
  end

  test "returns bad request for malformed JSON" do
    post webhooks_sns_ses_url,
      params: "not json",
      headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
  end

  test "returns bad request when required fields are missing" do
    post webhooks_sns_ses_url,
      params: { "Type" => "Notification" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
  end

  test "returns no content for unknown message type" do
    payload = {
      "Type" => "UnsubscribeConfirmation",
      "TopicArn" => TOPIC_ARN,
      "Message" => "You have been unsubscribed."
    }

    post webhooks_sns_ses_url,
      params: payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
  end

  test "returns bad request for non-JSON content type" do
    post webhooks_sns_ses_url,
      params: "<xml/>",
      headers: { "Content-Type" => "application/xml" }

    assert_response :bad_request
  end

  private

  def sns_notification(ses_event_json)
    {
      "Type" => "Notification",
      "TopicArn" => TOPIC_ARN,
      "Message" => ses_event_json
    }
  end

  def delivery_event(email)
    {
      "notificationType" => "Delivery",
      "mail" => {
        "messageId" => "test-message-id-001",
        "destination" => [ email ]
      },
      "delivery" => {
        "timestamp" => "2026-03-15T12:00:00.000Z",
        "recipients" => [ email ]
      }
    }.to_json
  end

  def bounce_event(email)
    {
      "notificationType" => "Bounce",
      "mail" => {
        "messageId" => "test-message-id-002",
        "destination" => [ email ]
      },
      "bounce" => {
        "bounceType" => "Permanent",
        "bounceSubType" => "General",
        "timestamp" => "2026-03-15T12:00:00.000Z",
        "bouncedRecipients" => [
          { "emailAddress" => email, "status" => "5.1.1", "diagnosticCode" => "smtp; 550 User unknown" }
        ]
      }
    }.to_json
  end

  def complaint_event(email)
    {
      "notificationType" => "Complaint",
      "mail" => {
        "messageId" => "test-message-id-003",
        "destination" => [ email ]
      },
      "complaint" => {
        "complainedRecipients" => [
          { "emailAddress" => email }
        ],
        "timestamp" => "2026-03-15T12:00:00.000Z",
        "complaintFeedbackType" => "abuse"
      }
    }.to_json
  end
end
