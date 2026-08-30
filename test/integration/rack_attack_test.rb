require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  def setup
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    @client = Client.create!(
      name: "Throttle Test",
      password: "senha123",
      password_confirmation: "senha123"
    )
  end

  test "5 primeiras tentativas não retornam 429" do
    5.times do
      post "/c/#{@client.access_token}/session", params: { password: "errada" }
      assert_not_equal 429, response.status
    end
  end

  test "6ª tentativa retorna 429" do
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    assert_equal 429, response.status
  end

  test "resposta 429 contém 'Muitas tentativas'" do
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    assert_includes response.body, "Muitas tentativas"
  end

  test "token diferente não é bloqueado quando outro token está bloqueado" do
    outro = Client.create!(name: "Outro", password: "abc123", password_confirmation: "abc123")
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    post "/c/#{outro.access_token}/session", params: { password: "errada" }
    assert_not_equal 429, response.status
  end

  test "admin login bloqueado na 6ª tentativa" do
    6.times { post "/session", params: { email_address: "x@x.com", password: "errada" } }
    assert_equal 429, response.status
  end

  # ---------------------------------------------------------------------------
  # Throttle AI: api/ai_by_key — INFAPI-04
  # ---------------------------------------------------------------------------

  AI_THROTTLE_KEY = "ak_throttle_test_#{SecureRandom.hex(4)}"

  def ai_auth_headers
    { "Authorization" => "Bearer #{AI_THROTTLE_KEY}", "Content-Type" => "application/json" }
  end

  test "60 primeiras requisições ao namespace AI não retornam 429" do
    original = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_THROTTLE_KEY
    Rack::Attack.cache.store.clear
    60.times do |i|
      get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: ai_auth_headers
      assert_not_equal 429, response.status,
        "Requisição #{i + 1}/60 retornou 429 inesperadamente"
    end
  ensure
    ENV["AI_API_KEY"] = original
  end

  test "61ª requisição ao namespace AI retorna 429" do
    original = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_THROTTLE_KEY
    Rack::Attack.cache.store.clear
    61.times { get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: ai_auth_headers }
    assert_equal 429, response.status
  ensure
    ENV["AI_API_KEY"] = original
  end

  test "resposta 429 do throttle AI é JSON estruturado com code too_many_requests" do
    original = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_THROTTLE_KEY
    Rack::Attack.cache.store.clear
    61.times { get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: ai_auth_headers }
    assert_equal 429, response.status
    body = response.parsed_body
    assert_equal "too_many_requests", body.dig("errors", 0, "code"),
                 "Esperado code='too_many_requests', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  ensure
    ENV["AI_API_KEY"] = original
  end

  test "throttle AI não afeta requests fora do namespace /api/v1/ai/" do
    original = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_THROTTLE_KEY
    Rack::Attack.cache.store.clear
    61.times { get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: ai_auth_headers }
    # Após esgotar o throttle AI, login admin não deve ser afetado
    post "/session", params: { email_address: "outro@exemplo.com", password: "errada" }
    assert_not_equal 429, response.status
  ensure
    ENV["AI_API_KEY"] = original
  end

  # ---------------------------------------------------------------------------
  # Throttle webhook: webhooks/evolution_by_ip — PAIR-06 / T-26-12
  # ---------------------------------------------------------------------------

  def webhook_headers
    { "X-Webhook-Secret" => "irrelevante" }
  end

  test "120 primeiros POSTs ao webhook não retornam 429" do
    Rack::Attack.cache.store.clear
    120.times do |i|
      post "/webhooks/evolution", params: { instance: "qualquer", event: "connection.update" }, headers: webhook_headers
      assert_not_equal 429, response.status,
        "Requisição #{i + 1}/120 retornou 429 inesperadamente"
    end
  end

  test "121ª requisição ao webhook retorna 429" do
    Rack::Attack.cache.store.clear
    121.times { post "/webhooks/evolution", params: { instance: "qualquer", event: "connection.update" }, headers: webhook_headers }
    assert_equal 429, response.status
  end
end
