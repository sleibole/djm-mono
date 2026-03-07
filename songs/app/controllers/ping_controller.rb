class PingController < ApplicationController
  before_action :authenticate_jwt!, only: :create

  def show
    render json: { status: "ok", app: "songs" }
  end

  def create
    render json: { status: "authenticated", payload: jwt_payload }
  end
end
