# frozen_string_literal: true

require "test_helper"

class Api::V1::Admin::ClientsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password              = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)

    @admin_jwt = Api::JwtService.encode({ sub: @user.id.to_s, scope: "admin" })
    @auth_headers = {
      "Authorization" => "Bearer #{@admin_jwt}",
      "Content-Type"  => "application/json"
    }

    @client = Client.create!(name: "Cliente Teste", password: "SenhaCliente123!", active: true)
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  test "GET /api/v1/admin/clients retorna 200 com lista paginada" do
    get "/api/v1/admin/clients", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("meta", "pagination", "total_count").is_a?(Integer),
           "Esperado meta.pagination.total_count Integer, mas foi: #{body.dig('meta', 'pagination').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "GET /api/v1/admin/clients sem autenticação retorna 401" do
    get "/api/v1/admin/clients", headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end

  test "GET /api/v1/admin/clients respeita per_page" do
    # Garante ao menos 2 clientes no banco para confirmar que per_page=1 corta a lista
    Client.create!(name: "Cliente Extra", password: "SenhaExtra456!", active: true)

    get "/api/v1/admin/clients?per_page=1", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert_equal 1, body.dig("meta", "pagination", "per_page"),
                 "Esperado per_page=1, mas foi: #{body.dig('meta', 'pagination').inspect}"
  end

  test "GET /api/v1/admin/clients nunca retorna password nem portal_url" do
    get "/api/v1/admin/clients", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    data = body["data"]
    assert data.is_a?(Array), "Esperado data ser Array, mas foi: #{data.class}"
    data.each do |c|
      refute c.key?("password"),   "Item da lista NÃO deve ter 'password': #{c.inspect}"
      refute c.key?("portal_url"), "Item da lista NÃO deve ter 'portal_url': #{c.inspect}"
    end
  end

  test "POST /api/v1/admin/clients com dados válidos retorna 201 com portal_url e password" do
    post "/api/v1/admin/clients",
         params: { name: "Novo Cliente", password: "Senha123!" }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    assert body.dig("data", "portal_url").present?,
           "Esperado data.portal_url presente, mas foi: #{body.dig('data').inspect}"
    assert body.dig("data", "password").present?,
           "Esperado data.password presente, mas foi: #{body.dig('data').inspect}"
  end

  test "POST /api/v1/admin/clients sem nome retorna 422 com errors" do
    post "/api/v1/admin/clients",
         params: { password: "Senha123!" }.to_json,
         headers: @auth_headers

    assert_equal 422, response.status
    body = response.parsed_body
    assert body["errors"].any?,
           "Esperado errors não vazio, mas foi: #{body['errors'].inspect}"
  end
end
