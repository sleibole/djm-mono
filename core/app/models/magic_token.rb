class MagicToken < ApplicationRecord
  LIFETIME = 10.minutes

  belongs_to :user

  before_create :set_expiry

  def self.generate_for(user)
    user.magic_tokens.delete_all

    raw_token = SecureRandom.urlsafe_base64(32)
    magic_token = user.magic_tokens.create!(token_digest: digest(raw_token))
    [ magic_token, raw_token ]
  end

  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?
    find_by(token_digest: digest(raw_token))
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def valid_token?
    !consumed? && !expired?
  end

  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def consume!
    update!(consumed_at: Time.current)
  end

  private

  def set_expiry
    self.expires_at ||= LIFETIME.from_now
  end
end
