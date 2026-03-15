# frozen_string_literal: true

require "test_helper"

class SesSnsEventProcessorTest < ActiveSupport::TestCase
  test "delivery updates last_delivered_at for matching user" do
    user = users(:one)

    SesSnsEventProcessor.call(delivery_event(user.email))

    user.reload
    assert_not_nil user.last_delivered_at
    assert_equal "active", user.email_status
  end

  test "bounce marks matching user as bounced" do
    user = users(:one)

    SesSnsEventProcessor.call(bounce_event(user.email))

    user.reload
    assert_equal "bounced", user.email_status
    assert_equal "Permanent / General", user.email_status_reason
    assert_not_nil user.last_bounced_at
  end

  test "complaint marks matching user as complained" do
    user = users(:one)

    SesSnsEventProcessor.call(complaint_event(user.email))

    user.reload
    assert_equal "complained", user.email_status
    assert_equal "abuse", user.email_status_reason
    assert_not_nil user.last_complained_at
  end

  test "does not raise for unknown notification type" do
    event = { "notificationType" => "Send", "mail" => { "messageId" => "abc" } }.to_json

    assert_nothing_raised { SesSnsEventProcessor.call(event) }
  end

  test "does not raise when no matching user exists" do
    assert_nothing_raised do
      SesSnsEventProcessor.call(bounce_event("nobody@example.com"))
    end
  end

  test "does not raise for malformed JSON" do
    assert_nothing_raised { SesSnsEventProcessor.call("not json") }
  end

  test "delivery handles multiple recipients" do
    user_one = users(:one)
    user_two = users(:two)

    event = {
      "notificationType" => "Delivery",
      "mail" => {
        "messageId" => "multi-001",
        "destination" => [ user_one.email, user_two.email ]
      },
      "delivery" => {
        "timestamp" => "2026-03-15T12:00:00.000Z",
        "recipients" => [ user_one.email, user_two.email ]
      }
    }.to_json

    SesSnsEventProcessor.call(event)

    assert_not_nil user_one.reload.last_delivered_at
    assert_not_nil user_two.reload.last_delivered_at
  end

  private

  def delivery_event(email)
    {
      "notificationType" => "Delivery",
      "mail" => {
        "messageId" => "test-msg-001",
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
        "messageId" => "test-msg-002",
        "destination" => [ email ]
      },
      "bounce" => {
        "bounceType" => "Permanent",
        "bounceSubType" => "General",
        "timestamp" => "2026-03-15T12:00:00.000Z",
        "bouncedRecipients" => [
          { "emailAddress" => email }
        ]
      }
    }.to_json
  end

  def complaint_event(email)
    {
      "notificationType" => "Complaint",
      "mail" => {
        "messageId" => "test-msg-003",
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
