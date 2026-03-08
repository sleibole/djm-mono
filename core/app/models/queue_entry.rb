class QueueEntry < ApplicationRecord
  STATUSES = %w[waiting up_next now_playing done skipped].freeze

  belongs_to :show
  belongs_to :participant

  validates :song_title, presence: true
  validates :song_artist, presence: true
  validates :position, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[waiting up_next]) }
  scope :completed, -> { where(status: %w[done skipped]) }

  def waiting?
    status == "waiting"
  end

  def now_playing?
    status == "now_playing"
  end

  def mark_now_playing!
    show.now_playing_entry&.mark_done!
    update!(status: "now_playing")
  end

  def mark_done!
    update!(status: "done", performed_at: Time.current)
  end

  def skip!
    update!(status: "skipped")
  end
end
