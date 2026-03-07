require "jwt"
require "djm_jwt/token"

module DjmJwt
  class Error < StandardError; end
  class ExpiredToken < Error; end
  class InvalidToken < Error; end

  ALGORITHM = "HS256"

  def self.secret
    ENV.fetch("DJM_JWT_SECRET") do
      raise Error, "DJM_JWT_SECRET environment variable is not set"
    end
  end
end
