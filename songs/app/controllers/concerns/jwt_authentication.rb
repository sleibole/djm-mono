module JwtAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_jwt!
    token = extract_token
    if token.nil?
      render json: { error: "Missing authorization token" }, status: :unauthorized
      return
    end

    begin
      @jwt_payload = DjmJwt::Token.verify(token)
    rescue DjmJwt::ExpiredToken
      render json: { error: "Token has expired" }, status: :unauthorized
    rescue DjmJwt::InvalidToken
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  def jwt_payload
    @jwt_payload
  end

  def extract_token
    header = request.headers["Authorization"]
    if header
      header.split(" ").last
    else
      params[:token]
    end
  end
end
