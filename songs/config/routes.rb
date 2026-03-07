Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "ping", to: "ping#show"
  post "ping", to: "ping#create"

  post "catalogs/:catalog_id/upload", to: "catalogs#upload", as: :catalog_upload
  get  "catalogs/:catalog_id/status", to: "catalogs#status", as: :catalog_status
end
