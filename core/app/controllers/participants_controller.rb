class ParticipantsController < ApplicationController
  before_action :require_login

  def autocomplete
    query = params[:q].to_s.strip
    return render(json: []) if query.blank?

    participants = current_user.participants
      .where("participants.name LIKE ?", "#{Participant.sanitize_sql_like(query)}%")
      .order(:name)
      .limit(10)
      .select(:id, :name)

    render json: participants.map { |p| { id: p.id, name: p.name } }
  end
end
