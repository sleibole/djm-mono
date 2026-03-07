class User < ApplicationRecord
  has_secure_password validations: false

  has_many :magic_tokens, dependent: :delete_all
  has_many :catalogs, dependent: :destroy

  enum :role, { audience: 0, dj: 1, admin: 2 }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  MAX_FAILED_ATTEMPTS = 10

  def email_confirmed?
    email_confirmed_at.present?
  end

  def confirm_email!
    update!(email_confirmed_at: Time.current) unless email_confirmed?
  end

  def locked?
    locked_at.present?
  end

  def lock!
    update!(locked_at: Time.current)
  end

  def unlock!
    update!(locked_at: nil, failed_login_attempts: 0)
  end

  def record_failed_login!
    increment!(:failed_login_attempts)
    lock! if failed_login_attempts >= MAX_FAILED_ATTEMPTS
  end

  def reset_failed_logins!
    update!(failed_login_attempts: 0, locked_at: nil) if failed_login_attempts > 0 || locked?
  end

  def has_password?
    password_digest.present?
  end
end
