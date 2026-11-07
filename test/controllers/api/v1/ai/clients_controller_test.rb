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

  # ---------------------------------------------------------------------------
  # GET /api/v1/ai/clients/:id/whatsapp_groups — fase 32 (D-06, D-13)
  # ---------------------------------------------------------------------------

  test "GET /whatsapp_groups sem autenticação retorna 401" do
    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups",
        headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET /whatsapp_groups cliente inexistente retorna 404 not_found" do
    get "/api/v1/ai/clients/0/whatsapp_groups", headers: @auth_headers

    assert_equal 404, response.status
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET /whatsapp_groups devolve só os grupos ativos com as chaves exatas" do
    instance = build_instance_with_groups!(@client, [
      { remote_jid: "ativo-1@g.us", subject: "Grupo Ativo Um" },
      { remote_jid: "ativo-2@g.us", subject: "Grupo Ativo Dois" },
      { remote_jid: "inativo@g.us", subject: "Grupo Inativo", active: false }
    ])

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert_equal [], body["errors"]
    assert_equal 2, body["data"].size
    assert_equal %w[display_name id remote_jid], body["data"].flat_map(&:keys).uniq.sort
    assert_equal instance.whatsapp_groups.where(active: true).pluck(:id).sort, body["data"].map { |g| g["id"] }.sort
    assert_not_includes body["data"].map { |g| g["remote_jid"] }, "inativo@g.us"
  end

  test "GET /whatsapp_groups ordena por subject crescente, nulos por último, depois remote_jid" do
    build_instance_with_groups!(@client, [
      { remote_jid: "z-nulo@g.us", subject: nil },
      { remote_jid: "b@g.us", subject: "Beta" },
      { remote_jid: "a2@g.us", subject: "Alfa" },
      { remote_jid: "a1@g.us", subject: "Alfa" },
      { remote_jid: "a-nulo@g.us", subject: nil }
    ])

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers

    assert_equal 200, response.status
    assert_equal %w[a1@g.us a2@g.us b@g.us a-nulo@g.us z-nulo@g.us],
                 response.parsed_body["data"].map { |g| g["remote_jid"] }
  end

  test "GET /whatsapp_groups usa o rótulo de fallback quando subject é nulo" do
    build_instance_with_groups!(@client, [ { remote_jid: "sem-nome-123456@g.us", subject: nil } ])

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers

    assert_equal 200, response.status
    display_name = response.parsed_body.dig("data", 0, "display_name")
    assert display_name.start_with?("Grupo sem nome ("),
           "Esperado fallback 'Grupo sem nome (', mas foi: #{display_name.inspect}"
  end

  test "GET /whatsapp_groups cliente sem instância retorna 200 com lista vazia" do
    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert_equal [], body["data"]
    assert_equal 0, body.dig("meta", "pagination", "total_count")
  end

  test "GET /whatsapp_groups nunca lista grupos de outro cliente" do
    build_instance_with_groups!(@client, [ { remote_jid: "meu@g.us", subject: "Meu Grupo" } ])
    build_instance_with_groups!(@another_client, [ { remote_jid: "alheio@g.us", subject: "Grupo Alheio" } ])

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers

    assert_equal 200, response.status
    assert_equal [ "meu@g.us" ], response.parsed_body["data"].map { |g| g["remote_jid"] }
  end

  test "GET /whatsapp_groups isola clientes-irmãos que compartilham o instance_name (fase 31)" do
    shared_name = "livia_client_sibling_#{SecureRandom.hex(4)}"
    build_instance_with_groups!(@client, [ { remote_jid: "irmao-a@g.us", subject: "Grupo do Irmão A" } ],
                                instance_name: shared_name)
    build_instance_with_groups!(@another_client, [ { remote_jid: "irmao-b@g.us", subject: "Grupo do Irmão B" } ],
                                instance_name: shared_name)
    assert_equal @client.whatsapp_instance.instance_name, @another_client.whatsapp_instance.instance_name

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", headers: @auth_headers
    assert_equal [ "irmao-a@g.us" ], response.parsed_body["data"].map { |g| g["remote_jid"] }

    get "/api/v1/ai/clients/#{@another_client.id}/whatsapp_groups", headers: @auth_headers
    assert_equal [ "irmao-b@g.us" ], response.parsed_body["data"].map { |g| g["remote_jid"] }
  end

  test "GET /whatsapp_groups pagina com per_page e limita a 100" do
    build_instance_with_groups!(@client, (1..5).map { |i| { remote_jid: format("pag-%02d@g.us", i), subject: format("Grupo %02d", i) } })

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", params: { per_page: 2 }, headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert_equal 2, body["data"].size
    assert_equal 5, body.dig("meta", "pagination", "total_count")
    assert_equal 3, body.dig("meta", "pagination", "total_pages")
    assert_equal 2, body.dig("meta", "pagination", "per_page")

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", params: { per_page: 500 }, headers: @auth_headers

    assert_equal 200, response.status
    assert_equal 100, response.parsed_body.dig("meta", "pagination", "per_page")
  end

  test "GET /whatsapp_groups com page invalida retorna 400 bad_request e nunca 500" do
    build_instance_with_groups!(@client, [ { remote_jid: "pg-01@g.us", subject: "Grupo 01" } ])

    %w[abc 0 -1].each do |page|
      get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", params: { page: page }, headers: @auth_headers

      assert_equal 400, response.status, "page=#{page}"
      assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
    end
  end

  test "GET /whatsapp_groups com pagina fora do intervalo continua 404 page_out_of_range" do
    build_instance_with_groups!(@client, [ { remote_jid: "pg-02@g.us", subject: "Grupo 02" } ])

    get "/api/v1/ai/clients/#{@client.id}/whatsapp_groups", params: { page: 99 }, headers: @auth_headers

    assert_equal 404, response.status
    assert_equal "page_out_of_range", response.parsed_body.dig("errors", 0, "code")
  end

  private

  # Cria a instância do cliente (conectada) com os grupos dados; active: true por padrão.
  def build_instance_with_groups!(client, groups, instance_name: WhatsappInstance.evolution_name_for(client))
    instance = client.create_whatsapp_instance!(
      instance_name:    instance_name,
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    groups.each do |attrs|
      instance.whatsapp_groups.create!({ active: true, synced_at: Time.current }.merge(attrs))
    end
    instance
  end
end
