# frozen_string_literal: true

require "test_helper"

class Api::V1::Ai::ArtesControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  setup do
    @original_ai_key = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @auth_headers = {
      "Authorization" => "Bearer #{AI_API_KEY}",
      "Content-Type"  => "application/json"
    }
    @client = Client.create!(name: "Cliente AI Teste", password: "SenhaIA123!", active: true)
  end

  teardown do
    ENV["AI_API_KEY"] = @original_ai_key
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/ai/artes — APIAI-01
  # ---------------------------------------------------------------------------

  test "GET sem autenticação retorna 401" do
    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30",
        headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "unauthorized", body.dig("errors", 0, "code"),
                 "Esperado code='unauthorized', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  end

  test "GET com from/to válidos retorna 200 com envelope" do
    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("meta", "pagination", "total_count").is_a?(Integer),
           "Esperado meta.pagination.total_count Integer, mas foi: #{body.dig('meta', 'pagination').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "GET sem from retorna 400" do
    get "/api/v1/ai/artes", headers: @auth_headers

    assert_equal 400, response.status
  end

  test "GET com data inválida retorna 400" do
    get "/api/v1/ai/artes?from=nao-e-data&to=2026-06-30", headers: @auth_headers

    assert_equal 400, response.status
    body = response.parsed_body
    assert_equal "bad_request", body.dig("errors", 0, "code"),
                 "Esperado code='bad_request', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  end

  test "GET retorna somente artes approved" do
    Arte.create!(
      title:        "Arte Aprovada AI",
      scheduled_on: Date.new(2026, 6, 15),
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/approved.jpg",
      client:       @client,
      status:       :approved
    )
    Arte.create!(
      title:        "Arte Pendente AI",
      scheduled_on: Date.new(2026, 6, 15),
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/pending.jpg",
      client:       @client,
      status:       :pending
    )

    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body["data"].any?, "Esperado ao menos uma arte aprovada"
    assert body["data"].all? { |a| a["status"] == "approved" },
           "Esperado apenas artes approved, mas encontrou: #{body['data'].map { |a| a['status'] }.uniq.inspect}"
  end

  test "GET filtra por client_id" do
    outro_cliente = Client.create!(name: "Outro Cliente AI", password: "OutroAI123!", active: true)

    Arte.create!(
      title:        "Arte do Cliente Principal",
      scheduled_on: Date.new(2026, 6, 15),
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/principal.jpg",
      client:       @client,
      status:       :approved
    )
    arte_outro = Arte.create!(
      title:        "Arte do Outro Cliente",
      scheduled_on: Date.new(2026, 6, 15),
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/outro.jpg",
      client:       outro_cliente,
      status:       :approved
    )

    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30&client_id=#{@client.id}", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    ids_retornados = body["data"].map { |a| a["client_id"] }
    assert ids_retornados.all? { |id| id == @client.id },
           "Esperado somente artes do cliente #{@client.id}, mas encontrou client_ids: #{ids_retornados.uniq.inspect}"
    refute_includes body["data"].map { |a| a["id"] }, arte_outro.id,
                    "Arte do outro cliente não deveria aparecer no filtro por client_id"
  end

  test "GET retorna paginação no meta" do
    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    pagination_keys = body.dig("meta", "pagination").keys.sort
    assert_equal %w[page per_page total_count total_pages].sort, pagination_keys,
                 "Esperado chaves de paginação corretas, mas foi: #{pagination_keys.inspect}"
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/ai/artes — APIAI-02
  # ---------------------------------------------------------------------------

  test "POST com external_url retorna 201" do
    post "/api/v1/ai/artes",
         params: {
           title:        "Arte IA via Link",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id,
           external_url: "https://drive.google.com/file/ai-test"
         }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    assert_equal "link", body.dig("data", "media_source_type"),
                 "Esperado media_source_type='link', mas foi: #{body.dig('data', 'media_source_type').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "POST com media_file retorna 400" do
    post "/api/v1/ai/artes",
         params: {
           title:        "Arte IA com Upload",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id,
           media_file:   "blob_data_simulado"
         }.to_json,
         headers: @auth_headers

    assert_equal 400, response.status
    body = response.parsed_body
    assert_equal "bad_request", body.dig("errors", 0, "code"),
                 "Esperado code='bad_request', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  end

  test "POST sem external_url retorna 422" do
    post "/api/v1/ai/artes",
         params: {
           title:        "Arte IA Sem Midia",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id
           # sem external_url e sem media_file
         }.to_json,
         headers: @auth_headers

    assert_equal 422, response.status
    body = response.parsed_body
    assert body["errors"].any?,
           "Esperado errors não vazio (media_source_present), mas foi: #{body['errors'].inspect}"
  end

  test "POST sem autenticação retorna 401" do
    post "/api/v1/ai/artes",
         params: {
           title:        "Arte IA Sem Auth",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id,
           external_url: "https://drive.google.com/file/sem-auth"
         }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end
end
