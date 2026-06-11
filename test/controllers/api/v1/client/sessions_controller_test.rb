# frozen_string_literal: true

require "test_helper"

class Api::V1::Client::SessionsControllerTest < ActionDispatch::IntegrationTest
  CLIENT_ACCESS_TOKEN = "testtoken_api_client_abc123"
  CLIENT_PASSWORD     = "SenhaCliente456!"

  setup do
    # Inject a test-only JWT_SECRET so Api::JwtService can encode without
    # credentials.yml.enc being configured (T-21-21; plan 21-05 step 1 adds the real secret).
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    Client.find_or_create_by!(access_token: CLIENT_ACCESS_TOKEN) do |c|
      c.name                  = "Test API Client"
      c.password              = CLIENT_PASSWORD
      c.password_confirmation = CLIENT_PASSWORD
      c.active                = true
    end
    @client = Client.find_by!(access_token: CLIENT_ACCESS_TOKEN)
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  test "POST /api/v1/client/session com credenciais válidas retorna 201 e token JWT" do
    post "/api/v1/client/session",
         params: { access_token: CLIENT_ACCESS_TOKEN, password: CLIENT_PASSWORD }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 201, response.status
    body = response.parsed_body
    assert body.dig("data", "token").present?,
           "Esperado data.token presente, mas foi: #{body.inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "POST /api/v1/client/session com access_token inexistente retorna 401 invalid_credentials" do
    post "/api/v1/client/session",
         params: { access_token: "token_que_nao_existe_xyz", password: CLIENT_PASSWORD }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "invalid_credentials", body.dig("errors", 0, "code"),
                 "Esperado errors[0].code == 'invalid_credentials', mas foi: #{body.inspect}"
  end

  test "POST /api/v1/client/session com senha errada retorna 401 invalid_credentials" do
    post "/api/v1/client/session",
         params: { access_token: CLIENT_ACCESS_TOKEN, password: "senhaerrada" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "invalid_credentials", body.dig("errors", 0, "code"),
                 "Esperado errors[0].code == 'invalid_credentials', mas foi: #{body.inspect}"
  end
end
