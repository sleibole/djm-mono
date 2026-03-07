module DjmJwt
  module Token
    module_function

    def generate(payload, expires_in: 300)
      payload = payload.transform_keys(&:to_s)
      payload["exp"] = (Time.now + expires_in).to_i unless payload.key?("exp")
      payload["iat"] = Time.now.to_i

      JWT.encode(payload, DjmJwt.secret, DjmJwt::ALGORITHM)
    end

    def verify(token)
      decoded = JWT.decode(token, DjmJwt.secret, true, algorithm: DjmJwt::ALGORITHM)
      decoded.first
    rescue JWT::ExpiredSignature
      raise DjmJwt::ExpiredToken, "Token has expired"
    rescue JWT::DecodeError => e
      raise DjmJwt::InvalidToken, "Invalid token: #{e.message}"
    end
  end
end
