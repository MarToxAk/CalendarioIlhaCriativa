# frozen_string_literal: true

require "test_helper"

class Api::V1::Client::ApprovalResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    # Admin necessário para callback Arte#broadcasts_revised_to_all (User.order(:id).first)
    User.find_or_create_by!(email_address: "admin@ilhacriativa.com.br") do |u|
      u.password              = "SenhaSegura123!"
      u.password_confirmation = "SenhaSegura123!"
    end

    @client = Client.create!(name: "Cliente API Teste", password: "SenhaCliente456!", active: true)
    @client_jwt = Api::JwtService.encode({ sub: @client.id.to_s, scope: "client" })
    @auth_headers = {
      "Authorization" => "Bearer #{@client_jwt}",
      "Content-Type"  => "application/json"
    }

    @arte = Arte.create!(
      client:       @client,
      title:        "Arte Teste",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/arte.jpg",
      status:       :pending
    )
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/client/artes/:arte_id/approval_responses (APICLI-03)
  # ---------------------------------------------------------------------------

  test "POST com decision=approved retorna 201 com campos D-08" do
    post "/api/v1/client/artes/#{@arte.id}/approval_responses",
         params:  { decision: "approved" }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    # Verificar todos os 5 campos D-08
    %w[id decision comment responded_at arte_status].each do |campo|
      assert body["data"].key?(campo),
             "Campo '#{campo}' ausente na resposta D-08. Chaves presentes: #{body['data'].keys.inspect}"
    end
    assert_equal "approved", body.dig("data", "decision"),
                 "Esperado decision == 'approved', mas foi: #{body.dig('data', 'decision').inspect}"
    assert body.dig("data", "arte_status").present?,
           "Esperado arte_status presente, mas foi: #{body.dig('data', 'arte_status').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "POST com decision=change_requested e comment retorna 201 (D-06 — comentario opcional)" do
    post "/api/v1/client/artes/#{@arte.id}/approval_responses",
         params:  { decision: "change_requested", comment: "Favor ajustar cor" }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    assert_equal "change_requested", body.dig("data", "decision"),
                 "Esperado decision == 'change_requested', mas foi: #{body.dig('data', 'decision').inspect}"
    assert_equal "Favor ajustar cor", body.dig("data", "comment"),
                 "Esperado comment == 'Favor ajustar cor', mas foi: #{body.dig('data', 'comment').inspect}"
  end

  test "POST retorna 400 para decision invalido (D-10 — enum guard)" do
    post "/api/v1/client/artes/#{@arte.id}/approval_responses",
         params:  { decision: "invalido" }.to_json,
         headers: @auth_headers

    assert_equal 400, response.status
    body = response.parsed_body
    assert body["errors"].any?,
           "Esperado errors nao vazio para decision invalido, mas foi: #{body['errors'].inspect}"
  end

  test "POST retorna 422 para arte ja approved (D-10 — arte_must_be_pending)" do
    @arte.update!(status: :approved)

    post "/api/v1/client/artes/#{@arte.id}/approval_responses",
         params:  { decision: "approved" }.to_json,
         headers: @auth_headers

    assert_equal 422, response.status
    body = response.parsed_body
    assert body["errors"].any?,
           "Esperado errors nao vazio para arte approved, mas foi: #{body['errors'].inspect}"
  end

  test "POST retorna 201 para arte revised (D-08 — re-aprovacao permitida)" do
    arte_revised = Arte.create!(
      client:       @client,
      title:        "Arte Revisada",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/revised.jpg",
      status:       :revised
    )

    post "/api/v1/client/artes/#{arte_revised.id}/approval_responses",
         params:  { decision: "approved" }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    assert_equal "approved", body.dig("data", "decision"),
                 "Re-aprovacao de arte revised deve retornar decision == 'approved'"
  end

  test "POST retorna 404 para arte de outro cliente (D-09 — cross-client)" do
    @outro_cliente = Client.create!(name: "Outro Cliente", password: "SenhaOutro999!", active: true)
    @arte_outro = Arte.create!(
      client:       @outro_cliente,
      title:        "Arte do Outro Cliente",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/outro.jpg",
      status:       :pending
    )

    post "/api/v1/client/artes/#{@arte_outro.id}/approval_responses",
         params:  { decision: "approved" }.to_json,
         headers: @auth_headers

    assert_equal 404, response.status
  end

  test "POST sem autenticacao retorna 401" do
    post "/api/v1/client/artes/#{@arte.id}/approval_responses",
         params:  { decision: "approved" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end
end
