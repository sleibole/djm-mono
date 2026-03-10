class Catalog < ApplicationRecord
  VARIANT_DISPLAY_OPTIONS = %w[none version id].freeze

  belongs_to :user
  has_many :shows, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :variant_display, inclusion: { in: VARIANT_DISPLAY_OPTIONS }
  validates :songs_shard, presence: true, numericality: { only_integer: true, greater_than: 0 }

  attribute :songs_shard, default: -> { ENV.fetch("SONGS_SHARD_CURRENT", 1).to_i }

  def songs_app_url
    ENV["SONGS_SHARD_#{songs_shard}_URL"] || ENV.fetch("SONGS_APP_URL")
  end

  def songs_app_status
    @songs_app_status
  end

  def songs_app_status=(status)
    @songs_app_status = status
  end
end
