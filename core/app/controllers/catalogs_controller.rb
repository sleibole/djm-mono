class CatalogsController < ApplicationController
  before_action :require_login
  before_action :set_catalog, only: [:show, :upload_token, :update]

  def index
    @catalogs = current_user.catalogs.order(:name)
  end

  def new
  end

  def create
    @catalog = current_user.catalogs.build(catalog_params)
    if @catalog.save
      redirect_to @catalog, notice: "Catalog created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @songs_upload_url = "#{ENV.fetch('SONGS_APP_URL')}/catalogs/#{@catalog.id}/upload"
  end

  def update
    if @catalog.update(catalog_params)
      redirect_to @catalog, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def upload_token
    token = DjmJwt::Token.generate(
      { user_id: current_user.id, catalog_id: @catalog.id },
      expires_in: 300
    )
    render json: { token: token }
  end

  private

  def set_catalog
    @catalog = current_user.catalogs.find(params[:id])
  end

  def catalog_params
    params.require(:catalog).permit(:name, :variant_display)
  end
end
