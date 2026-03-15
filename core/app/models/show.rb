class Show < ApplicationRecord
  SHOW_TYPES = %w[karaoke dj].freeze
  ROTATION_STYLES = %w[standard].freeze
  STATUSES = %w[scheduled active ended].freeze

  belongs_to :catalog, optional: true
  belongs_to :user
  has_many :queue_entries, -> { order(:position) }, dependent: :destroy

  before_validation :generate_slug, on: :create

  validates :show_type, inclusion: { in: SHOW_TYPES }
  validates :rotation_style, inclusion: { in: ROTATION_STYLES }
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true, unless: :scheduled?
  validates :slug, presence: true, uniqueness: { scope: :user_id },
                   format: { with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/,
                             message: "must be lowercase letters, numbers, and hyphens" }

  scope :scheduled, -> { where(status: "scheduled") }
  scope :active, -> { where(status: "active") }
  scope :ended, -> { where(status: "ended") }

  def karaoke?
    show_type == "karaoke"
  end

  def dj?
    show_type == "dj"
  end

  def participant_label
    karaoke? ? "Singer" : "Guest"
  end

  def participant_label_for_requests
    karaoke? ? "Singer" : "Requester"
  end

  def has_catalog?
    catalog_id.present?
  end

  def scheduled?
    status == "scheduled"
  end

  def active?
    status == "active"
  end

  def ended?
    status == "ended"
  end

  def display_name
    name.presence || catalog&.name || "Untitled Show"
  end

  def start!
    update!(status: "active", started_at: Time.current)
  end

  def end_show!
    update!(status: "ended", ended_at: Time.current)
  end

  def waiting_entries
    queue_entries.where(status: "waiting")
  end

  def now_playing_entry
    queue_entries.find_by(status: "now_playing")
  end

  def next_position
    (queue_entries.maximum(:position) || 0) + 1
  end

  def songs_limit_reached?(participant)
    return false if max_songs_per_singer.nil?
    queue_entries.where(participant: participant, status: %w[waiting pending]).count >= max_songs_per_singer
  end

  def pending_entries
    queue_entries.where(status: "pending").order(:created_at)
  end

  def public_url(host: ENV.fetch("CORE_APP_URL", "http://localhost:3000"))
    "#{host}/dj/#{user.slug}/shows/#{slug}"
  end

  def dj_profile_url(host: ENV.fetch("CORE_APP_URL", "http://localhost:3000"))
    "#{host}/dj/#{user.slug}"
  end

  private

  def generate_slug
    return if slug.present?

    base = name&.parameterize.presence || catalog&.name&.parameterize.presence || "show-#{SecureRandom.alphanumeric(4).downcase}"

    candidate = base.first(30)
    counter = 1
    while Show.exists?(user_id: user_id, slug: candidate)
      candidate = "#{base.first(26)}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end
end
