class User < ApplicationRecord
  has_secure_password validations: false

  has_many :magic_tokens, dependent: :delete_all
  has_many :catalogs, dependent: :destroy
  has_many :shows, dependent: :destroy
  has_many :participants, foreign_key: :dj_id, dependent: :destroy

  enum :role, { audience: 0, dj: 1, admin: 2 }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :slug, uniqueness: true, allow_nil: true,
                   length: { minimum: 3, maximum: 30 },
                   format: { with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/,
                             message: "must be lowercase letters, numbers, and hyphens (can't start or end with a hyphen)" }
  validates :display_name, length: { maximum: 50 }, allow_nil: true

  normalizes :slug, with: ->(slug) { slug.strip.downcase }

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

  def public_name
    display_name.presence || slug
  end

  def ensure_slug!
    return slug if slug.present?

    base = "dj-#{SecureRandom.alphanumeric(6).downcase}"

    candidate = base
    counter = 1
    while User.exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    update!(slug: candidate)
    candidate
  end
end
