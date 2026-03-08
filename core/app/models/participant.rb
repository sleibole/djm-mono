class Participant < ApplicationRecord
  belongs_to :dj, class_name: "User", foreign_key: :dj_id
  belongs_to :user, optional: true
  has_many :queue_entries, dependent: :destroy

  validates :name, presence: true

  scope :stale, -> { where(user_id: nil).where("last_active_at < ?", 2.weeks.ago) }

  def touch_activity!
    update!(last_active_at: Time.current)
  end
end
