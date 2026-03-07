class CatalogsController < ApplicationController
  before_action :require_login
  before_action :set_catalog, only: :show

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
    @upload_token = DjmJwt::Token.generate(
      { user_id: current_user.id, catalog_id: @catalog.id },
      expires_in: 300
    )
    @songs_upload_url = "#{ENV.fetch('SONGS_APP_URL')}/catalogs/#{@catalog.id}/upload"
  end

  private

  def set_catalog
    @catalog = current_user.catalogs.find(params[:id])
  end

  def catalog_params
    params.require(:catalog).permit(:name)
  end
end
