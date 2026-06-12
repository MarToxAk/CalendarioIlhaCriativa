# frozen_string_literal: true

require "test_helper"

class Api::V1::Client::ArtesControllerTest < ActionDispatch::IntegrationTest
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
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/client/artes — index (APICLI-01)
  # ---------------------------------------------------------------------------

  test "GET /api/v1/client/artes retorna 200 com meta.pagination" do
    Arte.create!(
      client:       @client,
      title:        "Arte Pendente",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/arte.jpg",
      status:       :pending
    )

    get "/api/v1/client/artes", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("meta", "pagination", "total_count").is_a?(Integer),
           "Esperado meta.pagination.total_count Integer, mas foi: #{body.dig('meta', 'pagination').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "GET retorna apenas pending e revised — nao approved nem change_requested (D-01)" do
    Arte.create!(client: @client, title: "Pendente",          scheduled_on: Date.current, platform: :instagram, media_type: :image, external_url: "https://example.com/p.jpg", status: :pending)
    Arte.create!(client: @client, title: "Revisada",          scheduled_on: Date.current, platform: :instagram, media_type: :image, external_url: "https://example.com/r.jpg", status: :revised)
    Arte.create!(client: @client, title: "Aprovada",          scheduled_on: Date.current, platform: :instagram, media_type: :image, external_url: "https://example.com/a.jpg", status: :approved)
    Arte.create!(client: @client, title: "Pediu Alteracao",   scheduled_on: Date.current, platform: :instagram, media_type: :image, external_url: "https://example.com/c.jpg", status: :change_requested)

    get "/api/v1/client/artes", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    statuses = body["data"].map { |a| a["status"] }

    assert_includes statuses, "pending",  "Esperado 'pending' na listagem"
    assert_includes statuses, "revised",  "Esperado 'revised' na listagem"
    refute_includes statuses, "approved", "Nao esperado 'approved' na listagem (D-01)"
    refute_includes statuses, "change_requested", "Nao esperado 'change_requested' na listagem (D-01)"
  end

  test "Arte de outro cliente NAO aparece no index (D-09 — cross-client)" do
    @outro_cliente = Client.create!(name: "Outro Cliente", password: "SenhaOutro789!", active: true)
    arte_outro_cliente = Arte.create!(
      client:       @outro_cliente,
      title:        "Arte do Outro Cliente",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/outro.jpg",
      status:       :pending
    )

    get "/api/v1/client/artes", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    ids_retornados = body["data"].map { |a| a["id"] }
    refute_includes ids_retornados, arte_outro_cliente.id,
                    "Arte do outro cliente nao deve aparecer no index do @client (D-09)"
  end

  test "GET sem autenticacao retorna 401" do
    get "/api/v1/client/artes", headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/client/artes/:id — show (APICLI-02)
  # ---------------------------------------------------------------------------

  test "GET /api/v1/client/artes/:id retorna 200 com campos D-03" do
    arte = Arte.create!(
      client:       @client,
      title:        "Arte Show Test",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/show.jpg",
      status:       :pending
    )

    get "/api/v1/client/artes/#{arte.id}", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    campos_d03 = %w[id title caption scheduled_on approval_deadline platform media_type media_url status admin_reply approval_responses]
    campos_d03.each do |campo|
      assert body["data"].key?(campo),
             "Campo '#{campo}' ausente na resposta D-03. Chaves presentes: #{body['data'].keys.inspect}"
    end
    assert body.dig("data", "approval_responses").is_a?(Array),
           "Esperado approval_responses como Array, mas foi: #{body.dig('data', 'approval_responses').class}"
  end

  test "GET show inclui approval_responses e admin_reply (D-04)" do
    arte = Arte.create!(
      client:       @client,
      title:        "Arte com Resposta",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/comresposta.jpg",
      status:       :pending
    )
    ApprovalResponse.create!(
      arte:         arte,
      decision:     :approved,
      comment:      "Tudo certo",
      responded_at: Time.current
    )

    get "/api/v1/client/artes/#{arte.id}", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("data", "approval_responses").length >= 1,
           "Esperado ao menos 1 approval_response embutida"
    primeiro = body.dig("data", "approval_responses").first
    %w[id decision comment responded_at].each do |campo|
      assert primeiro.key?(campo),
             "Campo '#{campo}' ausente no approval_response embutido: #{primeiro.inspect}"
    end
  end

  test "GET show de arte de outro cliente retorna 404 (D-09)" do
    @outro_cliente = Client.create!(name: "Outro Cliente Show", password: "SenhaOutro999!", active: true)
    arte_outro = Arte.create!(
      client:       @outro_cliente,
      title:        "Arte do Outro — Show",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/outro_show.jpg",
      status:       :pending
    )

    get "/api/v1/client/artes/#{arte_outro.id}", headers: @auth_headers

    assert_equal 404, response.status
  end
end
