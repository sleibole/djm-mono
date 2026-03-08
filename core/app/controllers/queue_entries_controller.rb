class QueueEntriesController < ApplicationController
  before_action :require_login
  before_action :set_show
  before_action :require_active_show, only: [ :create, :move, :now_playing, :skip, :approve, :reject ]
  before_action :set_queue_entry, only: [ :destroy, :move, :now_playing, :mark_done, :skip, :approve, :reject ]

  def create
    participant = find_or_create_participant

    if @show.songs_limit_reached?(participant)
      redirect_to @show, alert: "#{participant.name} already has the maximum number of songs queued."
      return
    end

    @entry = @show.queue_entries.build(
      participant: participant,
      song_title: params[:song_title],
      song_artist: params[:song_artist],
      song_version: params[:song_version].presence,
      song_external_id: params[:song_external_id].presence,
      position: @show.next_position,
      status: "waiting"
    )

    if @entry.save
      participant.touch_activity!
      redirect_to @show, notice: "#{participant.name} added to the queue."
    else
      redirect_to @show, alert: "Could not add to queue: #{@entry.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    name = @entry.participant.name
    @entry.destroy
    reposition_entries!
    redirect_to @show, notice: "#{name} removed from queue."
  end

  def move
    new_position = params[:position].to_i
    return redirect_to(@show) if new_position < 1

    entries = @show.queue_entries.active.order(:position).to_a
    entries.delete(@entry)
    insert_index = [ new_position - 1, entries.size ].min
    entries.insert(insert_index, @entry)

    ActiveRecord::Base.transaction do
      entries.each_with_index do |entry, idx|
        entry.update_columns(position: idx + 1)
      end
    end

    redirect_to @show
  end

  def now_playing
    @entry.mark_now_playing!
    redirect_to @show
  end

  def mark_done
    @entry.mark_done!
    redirect_to @show
  end

  def skip
    @entry.skip!
    redirect_to @show
  end

  def approve
    @entry.approve!
    redirect_to @show, notice: "#{@entry.participant.name} approved and added to queue."
  end

  def reject
    @entry.reject!
    redirect_to @show, notice: "Request from #{@entry.participant.name} rejected."
  end

  private

  def set_show
    @show = current_user.shows.find(params[:show_id])
  end

  def set_queue_entry
    @entry = @show.queue_entries.find(params[:id])
  end

  def require_active_show
    unless @show.active?
      redirect_to @show, alert: "This show has ended."
    end
  end

  def find_or_create_participant
    if params[:participant_id].present?
      current_user.participants.find(params[:participant_id]).tap(&:touch_activity!)
    else
      current_user.participants.create!(name: params[:participant_name], last_active_at: Time.current)
    end
  end

  def reposition_entries!
    @show.queue_entries.active.order(:position).each_with_index do |entry, idx|
      entry.update_columns(position: idx + 1)
    end
  end
end
