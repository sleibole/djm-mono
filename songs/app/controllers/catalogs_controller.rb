class CatalogsController < ApplicationController
  before_action :authenticate_jwt!, only: :upload

  def upload
    catalog_id = jwt_payload["catalog_id"]
    user_id = jwt_payload["user_id"]

    unless params[:file].present?
      render json: { error: "No file provided" }, status: :unprocessable_entity
      return
    end

    if params[:file].size > 100.megabytes
      render json: { error: "File too large. Maximum size is 100MB." }, status: :payload_too_large
      return
    end

    record = CatalogRecord.find_or_initialize_by(catalog_id: catalog_id)
    record.user_id = user_id
    record.status = :pending
    record.error_details = nil
    record.csv_file.attach(params[:file])
    record.save!

    BuildCatalogJob.perform_later(record.id)

    render json: { status: "accepted", catalog_id: catalog_id }, status: :accepted
  end

  def status
    record = CatalogRecord.find_by(catalog_id: params[:catalog_id])

    if record.nil?
      render json: { status: "not_found" }, status: :not_found
      return
    end

    response = {
      catalog_id: record.catalog_id,
      status: record.status,
      active_db_version: record.active_db_version
    }

    response[:errors] = record.parsed_errors if record.failed?

    render json: response
  end
end
