class Catalog < ApplicationRecord
  VARIANT_DISPLAY_OPTIONS = %w[none version id].freeze

  belongs_to :user
  has_many :shows, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :variant_display, inclusion: { in: VARIANT_DISPLAY_OPTIONS }

  def songs_app_status
    @songs_app_status
  end

  def songs_app_status=(status)
    @songs_app_status = status
  end
end
