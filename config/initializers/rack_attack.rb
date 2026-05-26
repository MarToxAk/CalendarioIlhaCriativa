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

  Rack::Attack.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "text/html; charset=utf-8" },
      [ "<h1>Muitas tentativas</h1><p>Aguarde alguns instantes antes de tentar novamente.</p>" ]
    ]
  end
end
