class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

  throttle("client_portal/password_by_token", limit: 5, period: 20) do |req|
    if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
      req.path.match(%r{\A/c/([^/]+)/})[1]
    end
  end

  throttle("client_portal/password_by_ip", limit: 10, period: 60) do |req|
    req.ip if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
  end

  throttle("admin/login_by_ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/session" && req.post?
  end

  throttle("client_portal/token_enum_by_ip", limit: 20, period: 60) do |req|
    req.ip if req.path.match?(%r{\A/c/[^/]+\z}) && req.get?
  end

  throttle("api/admin_login_by_ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/api/v1/admin/session" && req.post?
  end

  throttle("api/client_login_by_ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/api/v1/client/session" && req.post?
  end

  throttle("api/ai_by_key", limit: 60, period: 60) do |req|
    if req.path.start_with?("/api/v1/ai/")
      req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip.presence
    end
  end

  throttle("api/ai_by_ip", limit: 30, period: 60) do |req|
    req.ip if req.path.start_with?("/api/v1/ai/")
  end

  Rack::Attack.throttled_responder = lambda do |request|
    if request.path.start_with?("/api/")
      [429, { "Content-Type" => "application/json" },
       ['{"data":null,"meta":{},"errors":[{"code":"too_many_requests","detail":"Aguarde antes de tentar novamente."}]}']]
    else
      [429, { "Content-Type" => "text/html; charset=utf-8" },
       ["<h1>Muitas tentativas</h1><p>Aguarde alguns instantes antes de tentar novamente.</p>"]]
    end
  end
end
