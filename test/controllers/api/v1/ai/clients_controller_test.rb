# frozen_string_literal: true

require "test_helper"

class Api::V1::Ai::ClientsControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  setup do
    @original_ai_key = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @auth_headers = {
      "Authorization" => "Bearer #{AI_API_KEY}",
      "Content-Type"  => "application/json"
    }
    @client = Client.create!(name: "Cliente AI Summary Teste", password: "SenhaIA123!", active: true)
    @another_client = Client.create!(name: "Outro Cliente AI", password: "OutroAI123!", active: true)
  end

  teardown do
    ENV["AI_API_KEY"] = @original_ai_key
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/ai/clients/:id/summary — APIAI-03
  # ---------------------------------------------------------------------------

  test "GET /summary sem autenticação retorna 401" do
    get "/api/v1/ai/clients/#{@client.id}/summary",
        headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end

  test "GET /summary cliente inexistente retorna 404" do
    get "/api/v1/ai/clients/0/summary", headers: @auth_headers

    assert_equal 404, response.status
    body = response.parsed_body
    assert_equal "not_found", body.dig("errors", 0, "code"),
                 "Esperado code='not_found', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  end

  test "GET /summary retorna 200 com campos corretos" do
    Arte.create!(
      title:        "Arte Summary 1",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/s1.jpg",
      client:       @client,
      status:       :approved
    )
    Arte.create!(
      title:        "Arte Summary 2",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/s2.jpg",
      client:       @client,
      status:       :pending
    )

    get "/api/v1/ai/clients/#{@client.id}/summary", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    data = body["data"]
    assert data.key?("total"),                  "Esperado campo 'total' no data"
    assert data.key?("approved_count"),         "Esperado campo 'approved_count' no data"
    assert data.key?("pending_count"),          "Esperado campo 'pending_count' no data"
    assert data.key?("change_requested_count"), "Esperado campo 'change_requested_count' no data"
    assert data.key?("revised_count"),          "Esperado campo 'revised_count' no data"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "GET /summary counts são corretos" do
    2.times do |i|
      arte = Arte.create!(
        title:        "Arte Approved #{i}",
        scheduled_on: Date.current,
        platform:     :instagram,
        media_type:   :image,
        external_url: "https://example.com/approved-#{i}.jpg",
        client:       @client
      )
      arte.update!(status: :approved)
    end

    Arte.create!(
      title:        "Arte Pending",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/pending.jpg",
      client:       @client
      # status default: :pending
    )

    get "/api/v1/ai/clients/#{@client.id}/summary", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    data = body["data"]
    assert_equal 3, data["total"],          "Esperado total=3, mas foi: #{data['total']}"
    assert_equal 2, data["approved_count"], "Esperado approved_count=2, mas foi: #{data['approved_count']}"
    assert_equal 1, data["pending_count"],  "Esperado pending_count=1, mas foi: #{data['pending_count']}"
  end

  test "GET /summary não inclui artes de outro cliente" do
    Arte.create!(
      title:        "Arte do Cliente Principal",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/principal.jpg",
      client:       @client,
      status:       :approved
    )

    # Criar artes para @another_client — não devem aparecer no summary de @client
    3.times do |i|
      Arte.create!(
        title:        "Arte Outro Cliente #{i}",
        scheduled_on: Date.current,
        platform:     :instagram,
        media_type:   :image,
        external_url: "https://example.com/outro-#{i}.jpg",
        client:       @another_client,
        status:       :approved
      )
    end

    get "/api/v1/ai/clients/#{@client.id}/summary", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    data = body["data"]
    assert_equal 1, data["total"],
                 "Esperado total=1 (somente artes de @client), mas foi: #{data['total']}"
  end
end
