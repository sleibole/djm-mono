class CatalogRecord < ApplicationRecord
  has_one_attached :csv_file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :catalog_id, presence: true, uniqueness: true
  validates :user_id, presence: true

  def next_version
    (active_db_version || 0) + 1
  end

  def db_filename(version = active_db_version)
    "catalog_#{catalog_id}_v#{version}.db"
  end

  def db_path(version = active_db_version)
    Rails.root.join("storage", "catalog_dbs", db_filename(version))
  end

  def parsed_errors
    return [] if error_details.blank?
    JSON.parse(error_details)
  rescue JSON::ParserError
    []
  end
end
