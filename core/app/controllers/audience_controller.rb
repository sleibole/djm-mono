class AudienceController < ApplicationController
  layout "audience"

  before_action :set_dj
  before_action :set_show, only: [ :show, :queue, :display, :create_request ]

  def dj_profile
    @active_shows = @dj.shows.active.includes(:catalog).order(started_at: :desc)
    @scheduled_shows = @dj.shows.scheduled.includes(:catalog).order(:scheduled_at)
  end

  def show
    @songs_app_url = @show.catalog&.songs_app_url
    @participant_name = session_participant&.name
  end

  def queue
    @now_playing = @show.now_playing_entry
    @waiting = @show.waiting_entries.includes(:participant)
    @participant = session_participant
    if @participant
      @my_pending = @show.queue_entries.where(participant: @participant, status: "pending")
      @my_rejected = @show.queue_entries.where(participant: @participant, status: "rejected")
    end
  end

  def display
    @now_playing = @show.now_playing_entry
    @waiting = @show.waiting_entries.includes(:participant)
    render layout: "display"
  end

  def create_request
    unless @show.active?
      message = @show.scheduled? ? "This show hasn't started yet." : "This show has ended and is no longer accepting requests."
      redirect_to audience_show_path(handle: @dj.slug, show_slug: @show.slug), alert: message
      return
    end

    name = params[:participant_name].to_s.strip
    if name.blank?
      redirect_to audience_show_path(handle: @dj.slug, show_slug: @show.slug),
                  alert: "Please enter your name."
      return
    end

    participant = find_or_create_participant(name)

    if @show.songs_limit_reached?(participant)
      redirect_to audience_show_path(handle: @dj.slug, show_slug: @show.slug),
                  alert: "You already have the maximum number of songs queued."
      return
    end

    status = @show.approval_required? ? "pending" : "waiting"
    position = @show.approval_required? ? 0 : @show.next_position

    entry = @show.queue_entries.build(
      participant: participant,
      song_title: params[:song_title],
      song_artist: params[:song_artist].presence || "Unknown",
      song_version: params[:song_version].presence,
      song_external_id: params[:song_external_id].presence,
      position: position,
      status: status
    )

    if entry.save
      participant.touch_activity!
      session[:audience_participant_id] = participant.id

      message = @show.approval_required? ?
        "Your request has been submitted! The host will review it shortly." :
        "You've been added to the queue!"
      redirect_to audience_queue_path(handle: @dj.slug, show_slug: @show.slug), notice: message
    else
      redirect_to audience_show_path(handle: @dj.slug, show_slug: @show.slug),
                  alert: "Could not submit request: #{entry.errors.full_messages.to_sentence}"
    end
  end

  private

  def set_dj
    @dj = User.find_by(slug: params[:handle])
    render "audience/not_found", status: :not_found unless @dj
  end

  def set_show
    return unless @dj
    @show = @dj.shows.find_by(slug: params[:show_slug])
    render "audience/show_not_found", status: :not_found unless @show
  end

  def find_or_create_participant(name)
    existing = @dj.participants.find_by(name: name)
    return existing if existing

    @dj.participants.create!(name: name, last_active_at: Time.current)
  end

  def session_participant
    return unless session[:audience_participant_id]
    @dj&.participants&.find_by(id: session[:audience_participant_id])
  end
end
