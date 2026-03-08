class Show < ApplicationRecord
  SHOW_TYPES = %w[karaoke dj].freeze
  ROTATION_STYLES = %w[standard].freeze
  STATUSES = %w[active ended].freeze

  belongs_to :catalog
  belongs_to :user
  has_many :queue_entries, -> { order(:position) }, dependent: :destroy

  validates :show_type, inclusion: { in: SHOW_TYPES }
  validates :rotation_style, inclusion: { in: ROTATION_STYLES }
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

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

  def active?
    status == "active"
  end

  def ended?
    status == "ended"
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
    queue_entries.where(participant: participant, status: "waiting").count >= max_songs_per_singer
  end
end
