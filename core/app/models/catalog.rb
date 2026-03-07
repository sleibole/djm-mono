class Catalog < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }

  def songs_app_status
    @songs_app_status
  end

  def songs_app_status=(status)
    @songs_app_status = status
  end
end
