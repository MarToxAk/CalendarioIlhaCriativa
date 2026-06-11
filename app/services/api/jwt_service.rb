# frozen_string_literal: true

module Api
  module Errors
    class TokenExpired < StandardError; end
    class TokenInvalid < StandardError; end
  end

  class JwtService
    ALGORITHM = "HS256".freeze
    DEFAULT_EXPIRY = (Rails.application.credentials.jwt_expiry_hours || 24).hours

    def self.encode(payload, expiry: DEFAULT_EXPIRY)
      full_payload = payload.merge(
        iat: Time.now.to_i,
        exp: expiry.from_now.to_i
      )
      JWT.encode(full_payload, secret, ALGORITHM)
    end

    def self.decode(token)
      decoded = JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })
      decoded.first.with_indifferent_access
    rescue JWT::ExpiredSignature
      raise Api::Errors::TokenExpired
    rescue JWT::DecodeError
      raise Api::Errors::TokenInvalid
    end

    def self.secret
      Rails.application.credentials.jwt_secret ||
        ENV.fetch("JWT_SECRET") { raise "JWT_SECRET not configured" }
    end
    private_class_method :secret
  end
end
