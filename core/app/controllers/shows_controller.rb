class ShowsController < ApplicationController
  before_action :require_login
  before_action :set_show, only: [ :show, :update, :end_show ]

  def index
    @active_shows = current_user.shows.active.includes(:catalog).order(started_at: :desc)
    @ended_shows = current_user.shows.ended.includes(:catalog).order(ended_at: :desc).limit(20)
  end

  def new
    @catalogs = current_user.catalogs.order(:name)
  end

  def create
    catalog = current_user.catalogs.find(params[:catalog_id])
    current_user.ensure_slug!

    @show = current_user.shows.build(
      catalog: catalog,
      show_type: params[:show_type].presence || current_user.default_show_type,
      rotation_style: current_user.default_rotation_style,
      max_songs_per_singer: current_user.default_max_songs_per_singer,
      status: "active",
      started_at: Time.current
    )

    if @show.save
      redirect_to @show, notice: "Show started!"
    else
      @catalogs = current_user.catalogs.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @queue_entries = @show.queue_entries.includes(:participant)
    @now_playing = @show.now_playing_entry
    @waiting = @show.waiting_entries.includes(:participant)
    @pending = @show.pending_entries.includes(:participant)
    @completed = @show.queue_entries.completed.includes(:participant).order(performed_at: :desc)
    @songs_app_url = @show.catalog.songs_app_url
  end

  def update
    if @show.update(show_params)
      redirect_to @show, notice: "Show settings updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def end_show
    @show.end_show!
    redirect_to shows_path, notice: "Show ended."
  end

  private

  def set_show
    @show = current_user.shows.find(params[:id])
  end

  def show_params
    params.require(:show).permit(:show_type, :rotation_style, :max_songs_per_singer, :approval_required, :manual_entry_enabled, :slug)
  end
end
