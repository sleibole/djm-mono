Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get  "signup", to: "registrations#new", as: :signup
  get  "signin", to: "sessions#new",      as: :login
  post "signin", to: "sessions#create_with_password"
  delete "logout", to: "sessions#destroy", as: :logout

  post "magic_links", to: "magic_links#create", as: :magic_links
  get  "auth/magic/:token", to: "magic_links#show", as: :auth_magic_link
  post "auth/magic/:token", to: "magic_links#redeem", as: :redeem_magic_link

  resources :catalogs, only: [ :index, :new, :create, :show, :update ] do
    post :upload_token, on: :member
  end

  resources :shows, only: [ :index, :new, :create, :show, :update ] do
    patch :end_show, on: :member
    patch :start_show, on: :member
    resources :queue_entries, only: [ :create, :destroy ] do
      member do
        patch :move
        patch :now_playing
        patch :mark_done
        patch :skip
        patch :approve
        patch :reject
      end
    end
  end

  get "participants/autocomplete", to: "participants#autocomplete"

  scope "dj/:handle", controller: :audience do
    get  "/",                          action: :dj_profile,     as: :dj_profile
    get  "shows/:show_slug",           action: :show,           as: :audience_show
    get  "shows/:show_slug/queue",     action: :queue,          as: :audience_queue
    get  "shows/:show_slug/display",  action: :display,        as: :audience_display
    post "shows/:show_slug/requests",  action: :create_request, as: :audience_request
  end

  get "docs/:slug", to: "docs#show", as: :doc

  get   "account", to: "account#show", as: :account
  patch "account/password", to: "account#update_password", as: :account_password
  delete "account/password", to: "account#remove_password"
  patch "account/slug", to: "account#update_slug", as: :account_slug
  patch "account/display_name", to: "account#update_display_name", as: :account_display_name

  get "landing/paper", to: "landing_pages#paper", as: :landing_paper

  root "home#show"
end
