# frozen_string_literal: true

require "test_helper"

class Api::V1::Admin::ApprovalResponsesControllerTest < ActionDispatch::IntegrationTest
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

    @client = Client.create!(
      name:     "Cliente Teste Aprovações",
      password: "SenhaCliente123!",
      active:   true
    )

    @arte = Arte.create!(
      client:       @client,
      title:        "Arte Histórico",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/arte.jpg",
      status:       :pending
    )

    @response1 = ApprovalResponse.create!(
      arte:         @arte,
      decision:     :approved,
      comment:      "Aprovado",
      responded_at: Time.current
    )

    @admin_jwt    = Api::JwtService.encode({ sub: @user.id.to_s, scope: "admin" })
    @auth_headers = { "Authorization" => "Bearer #{@admin_jwt}", "Content-Type" => "application/json" }
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  test "GET retorna 200 com lista de respostas e meta.arte_status" do
    get "/api/v1/admin/artes/#{@arte.id}/approval_responses",
        headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body["data"].is_a?(Array),
           "Esperado data como Array, mas foi: #{body['data'].class}"
    assert body.dig("meta", "arte_status").present?,
           "Esperado meta.arte_status presente, mas foi: #{body.dig('meta', 'arte_status').inspect}"
    assert_equal [], body["errors"]
  end

  test "GET inclui campos obrigatórios (D-11): id, decision, comment, responded_at, arte_status" do
    get "/api/v1/admin/artes/#{@arte.id}/approval_responses",
        headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    item = body["data"].first
    %w[id decision comment responded_at arte_status].each do |k|
      assert item.key?(k), "Falta campo #{k} na resposta: #{item.inspect}"
    end
    assert_equal "approved", item["decision"],
                 "Esperado decision == 'approved', mas foi: #{item['decision'].inspect}"
  end

  test "GET com arte inexistente retorna 404" do
    get "/api/v1/admin/artes/999999/approval_responses",
        headers: @auth_headers

    assert_equal 404, response.status
  end

  test "GET sem autenticação retorna 401" do
    get "/api/v1/admin/artes/#{@arte.id}/approval_responses",
        headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end
end
