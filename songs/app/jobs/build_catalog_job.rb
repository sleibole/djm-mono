class BuildCatalogJob < ApplicationJob
  queue_as :default

  def perform(catalog_record_id)
    record = CatalogRecord.find(catalog_record_id)
    record.update!(status: :processing)

    csv_content = record.csv_file.download

    validation = CsvValidator.new(csv_content).validate

    unless validation.valid?
      record.update!(
        status: :failed,
        error_details: validation.errors.to_json
      )
      return
    end

    new_version = record.next_version
    old_version = record.active_db_version

    song_count = CatalogDbBuilder.new(record, new_version).build

    record.update!(
      status: :ready,
      active_db_version: new_version,
      song_count: song_count,
      error_details: nil
    )

    cleanup_old_version(record, old_version) if old_version
  end

  private

  def cleanup_old_version(record, version)
    old_path = record.db_path(version)
    File.delete(old_path) if File.exist?(old_path)
  rescue StandardError => e
    Rails.logger.warn("Failed to clean up old catalog DB #{old_path}: #{e.message}")
  end
end
