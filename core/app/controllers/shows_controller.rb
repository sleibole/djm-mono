class ShowsController < ApplicationController
  before_action :require_login
  before_action :set_show, only: [ :show, :update, :end_show, :start_show ]

  def index
    @scheduled_shows = current_user.shows.scheduled.includes(:catalog).order(:scheduled_at)
    @active_shows = current_user.shows.active.includes(:catalog).order(started_at: :desc)
    @ended_shows = current_user.shows.ended.includes(:catalog).order(ended_at: :desc).limit(20)
  end

  def new
    @catalogs = current_user.catalogs.order(:name)
  end

  def create
    catalog = current_user.catalogs.find(params[:catalog_id])
    current_user.ensure_slug!

    scheduled_at = params[:scheduled_at].presence
    scheduling = scheduled_at.present?

    @show = current_user.shows.build(
      catalog: catalog,
      name: params[:name].presence,
      slug: params[:slug].presence,
      show_type: params[:show_type].presence || current_user.default_show_type,
      rotation_style: current_user.default_rotation_style,
      max_songs_per_singer: current_user.default_max_songs_per_singer,
      status: scheduling ? "scheduled" : "active",
      started_at: scheduling ? nil : Time.current,
      scheduled_at: scheduled_at
    )

    if @show.save
      notice = scheduling ? "Show scheduled!" : "Show started!"
      redirect_to @show, notice: notice
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

  def start_show
    @show.start!
    redirect_to @show, notice: "Show started!"
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
    params.require(:show).permit(:show_type, :rotation_style, :max_songs_per_singer, :approval_required, :manual_entry_enabled, :slug, :name, :scheduled_at)
  end
end
