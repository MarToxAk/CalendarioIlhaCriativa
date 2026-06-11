# frozen_string_literal: true

require "test_helper"

class Api::V1::Admin::ArtesControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    # Cria admin para JWT e para guard do callback Arte#broadcasts_revised_to_all
    # (User.order(:id).first é chamado no callback — sem User no DB, o guard retorna antes,
    # mas garante consistência com o padrão dos demais testes da fase)
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

    @client = Client.create!(name: "Cliente Arte Teste", password: "SenhaCliente123!", active: true)
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/artes
  # ---------------------------------------------------------------------------

  test "GET /api/v1/admin/artes retorna 200 com lista paginada" do
    get "/api/v1/admin/artes", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("meta", "pagination", "total_count").is_a?(Integer),
           "Esperado meta.pagination.total_count Integer, mas foi: #{body.dig('meta', 'pagination').inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "GET /api/v1/admin/artes sem autenticação retorna 401" do
    get "/api/v1/admin/artes", headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
  end

  test "GET /api/v1/admin/artes?client_id filtra por cliente" do
    outro_cliente = Client.create!(name: "Outro Cliente", password: "SenhaOutro123!", active: true)
    arte_do_outro = Arte.create!(
      title:        "Arte de Outro Cliente",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/outro.jpg",
      client:       outro_cliente
    )

    Arte.create!(
      title:        "Arte do Cliente Principal",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/principal.jpg",
      client:       @client
    )

    get "/api/v1/admin/artes?client_id=#{@client.id}", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    ids_retornados = body["data"].map { |a| a["id"] }
    refute_includes ids_retornados, arte_do_outro.id,
                    "Arte do outro cliente não deveria aparecer no filtro por client_id"
  end

  test "GET /api/v1/admin/artes?status=approved filtra por status" do
    Arte.create!(
      title:        "Arte Aprovada",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/aprovada.jpg",
      client:       @client,
      status:       :approved
    )
    Arte.create!(
      title:        "Arte Pendente",
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/pendente.jpg",
      client:       @client,
      status:       :pending
    )

    get "/api/v1/admin/artes?status=approved", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    assert body["data"].any?, "Esperado ao menos uma arte aprovada na resposta"
    body["data"].each do |arte|
      assert_equal "approved", arte["status"],
                   "Todos os itens retornados devem ter status 'approved', mas foi: #{arte['status']}"
    end
  end

  test "GET /api/v1/admin/artes?status=invalido retorna 400" do
    get "/api/v1/admin/artes?status=invalido", headers: @auth_headers

    assert_equal 400, response.status
  end

  test "GET /api/v1/admin/artes?month=YYYY-MM filtra por mes" do
    mes_alvo = Date.new(2025, 12, 15)
    mes_outro = Date.new(2025, 11, 10)

    arte_no_mes = Arte.create!(
      title:        "Arte de Dezembro",
      scheduled_on: mes_alvo,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/dezembro.jpg",
      client:       @client
    )
    arte_fora_mes = Arte.create!(
      title:        "Arte de Novembro",
      scheduled_on: mes_outro,
      platform:     :instagram,
      media_type:   :image,
      external_url: "https://example.com/novembro.jpg",
      client:       @client
    )

    get "/api/v1/admin/artes?month=2025-12", headers: @auth_headers

    assert_equal 200, response.status
    body = response.parsed_body
    ids_retornados = body["data"].map { |a| a["id"] }
    assert_includes ids_retornados, arte_no_mes.id,
                    "Arte de dezembro deve aparecer no filtro ?month=2025-12"
    refute_includes ids_retornados, arte_fora_mes.id,
                    "Arte de novembro não deve aparecer no filtro ?month=2025-12"
  end

  test "GET /api/v1/admin/artes?month=nao-data retorna 400" do
    get "/api/v1/admin/artes?month=nao-data", headers: @auth_headers

    assert_equal 400, response.status
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/admin/artes
  # ---------------------------------------------------------------------------

  test "POST /api/v1/admin/artes com external_url retorna 201 com media_source_type link" do
    post "/api/v1/admin/artes",
         params: {
           title:        "Arte com Link",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id,
           external_url: "https://drive.google.com/file/exemplo"
         }.to_json,
         headers: @auth_headers

    assert_equal 201, response.status
    body = response.parsed_body
    assert_equal "link", body.dig("data", "media_source_type"),
                 "Esperado media_source_type='link', mas foi: #{body.dig('data', 'media_source_type')}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "POST /api/v1/admin/artes com media_file retorna 201 com media_url e media_source_type upload" do
    file = fixture_file_upload(
      Rails.root.join("test/fixtures/files/sample.jpg"),
      "image/jpeg"
    )

    post "/api/v1/admin/artes",
         params: {
           title:        "Arte com Upload",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id,
           media_file:   file
         },
         headers: { "Authorization" => "Bearer #{@admin_jwt}" }
         # Sem Content-Type: application/json — Rack detecta multipart automaticamente

    assert_equal 201, response.status
    body = response.parsed_body
    assert body.dig("data", "media_url").present?,
           "Esperado data.media_url presente, mas foi: #{body.dig('data').inspect}"
    assert_equal "upload", body.dig("data", "media_source_type"),
                 "Esperado media_source_type='upload', mas foi: #{body.dig('data', 'media_source_type')}"
  end

  test "POST /api/v1/admin/artes sem midia retorna 422 com errors" do
    post "/api/v1/admin/artes",
         params: {
           title:        "Arte Sem Midia",
           scheduled_on: Date.current.to_s,
           platform:     "instagram",
           media_type:   "image",
           client_id:    @client.id
           # sem media_file nem external_url
         }.to_json,
         headers: @auth_headers

    assert_equal 422, response.status
    body = response.parsed_body
    assert body["errors"].any?,
           "Esperado errors não vazio (media_source_present), mas foi: #{body['errors'].inspect}"
  end
end
