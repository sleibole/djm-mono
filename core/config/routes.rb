Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "signup", to: "registrations#new", as: :signup
  get  "signin", to: "sessions#new",      as: :login
  post "signin", to: "sessions#create_with_password"
  delete "logout", to: "sessions#destroy", as: :logout

  post "magic_links", to: "magic_links#create", as: :magic_links
  get  "auth/magic/:token", to: "magic_links#show", as: :auth_magic_link
  post "auth/magic/:token", to: "magic_links#redeem", as: :redeem_magic_link

  resources :catalogs, only: [ :index, :new, :create, :show ] do
    post :upload_token, on: :member
  end

  get "docs/:slug", to: "docs#show", as: :doc

  get   "account", to: "account#show", as: :account
  patch "account/password", to: "account#update_password", as: :account_password
  delete "account/password", to: "account#remove_password"

  root "home#show"
end
