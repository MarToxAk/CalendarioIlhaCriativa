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
    # Sem Content-Type: o rack-test detecta o Rack::Test::UploadedFile em params e monta o
    # multipart com boundary. Um Content-Type JSON junto deixaria o teste enganoso.
    @multipart_headers = { "Authorization" => "Bearer #{AI_API_KEY}" }
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

  test "POST com media_file em texto (JSON) retorna 400" do
    assert_no_difference "Arte.count" do
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
    end

    assert_equal 400, response.status
    body = response.parsed_body
    assert_equal "bad_request", body.dig("errors", 0, "code"),
                 "Esperado code='bad_request', mas foi: #{body.dig('errors', 0, 'code').inspect}"
  end

  test "POST multipart com media_file retorna 201 com upload e media_url (D-01, D-05, D-07)" do
    assert_difference "Arte.count", 1 do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
           headers: @multipart_headers
    end

    assert_equal 201, response.status
    body = response.parsed_body
    assert_equal "upload", body.dig("data", "media_source_type")
    assert_equal "pending", body.dig("data", "status")
    assert body.dig("data", "media_url").present?,
           "Esperado data.media_url presente, mas foi: #{body['data'].inspect}"
    assert_equal [], body["errors"]

    arte = Arte.find(body.dig("data", "id"))
    assert arte.media_file.attached?
    assert_nil arte.external_url
  end

  test "POST multipart com falha de storage responde 503 e não deixa arte órfã (T-33-05)" do
    falha = ->(*_args, **_opts) { raise IOError, "s3 fora do ar" }

    ActiveStorage::Blob.service.stub(:upload, falha) do
      assert_no_difference [ "Arte.count", "ActiveStorage::Attachment.count" ] do
        post "/api/v1/ai/artes",
             params:  multipart_params(media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
             headers: @multipart_headers
      end
    end

    assert_equal 503, response.status
    body = response.parsed_body
    assert_equal "storage_unavailable", body.dig("errors", 0, "code")
    assert_nil body["data"]

    # Retry com o storage normal: cria exatamente uma arte, sem duplicata.
    assert_difference "Arte.count", 1 do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
           headers: @multipart_headers
    end
    assert_equal 201, response.status
  end

  test "POST multipart com arquivo e external_url retorna 422 (D-02)" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(
             external_url: "https://drive.google.com/file/ambos",
             media_file:   fixture_file_upload("sample.jpg", "image/jpeg")
           ),
           headers: @multipart_headers
    end

    assert_equal 422, response.status
    error = response.parsed_body.dig("errors", 0)
    assert_equal "Use arquivo OU link externo, não ambos", error["detail"]
    assert_equal "base", error["field"]
  end

  test "POST multipart com PDF disfarçado de .jpg retorna 422 (D-08, D-10)" do
    pdf = Tempfile.new([ "disfarce", ".jpg" ], binmode: true)
    begin
      pdf.write("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n")
      pdf.flush

      assert_rejected_without_effects do
        post "/api/v1/ai/artes",
             params:  multipart_params(media_file: Rack::Test::UploadedFile.new(pdf.path, "image/jpeg")),
             headers: @multipart_headers
      end
    ensure
      pdf.close!
    end

    assert_equal 422, response.status
    error = response.parsed_body.dig("errors", 0)
    assert_equal "media_file", error["field"]
    assert_includes error["detail"], "imagem ou vídeo"
  end

  test "POST multipart com arquivo acima de 50MB retorna 422 (D-04, D-08)" do
    grande = Tempfile.new([ "grande", ".jpg" ], binmode: true)
    begin
      grande.write(file_fixture("sample.jpg").binread)
      grande.write("\0" * (50.megabytes + 1))
      grande.flush

      assert_rejected_without_effects do
        post "/api/v1/ai/artes",
             params:  multipart_params(media_file: Rack::Test::UploadedFile.new(grande.path, "image/jpeg")),
             headers: @multipart_headers
      end
    ensure
      grande.close!
    end

    assert_equal 422, response.status
    error = response.parsed_body.dig("errors", 0)
    assert_equal "media_file", error["field"]
    assert_includes error["detail"], "50MB"
  end

  test "POST multipart caption_only sem arquivo nem link retorna 422 (D-06)" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_type: "caption_only", media_file: ""),
           headers: @multipart_headers
    end

    assert_equal 422, response.status
    error = response.parsed_body.dig("errors", 0)
    assert_equal "base", error["field"]
    assert_equal "Precisa de arquivo ou link externo", error["detail"]
  end

  test "POST com media_file em campo de texto do formulário retorna 400" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: "abc"),
           headers: @multipart_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "POST com media_file Hash em JSON retorna 400" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: { io: "x" }).to_json,
           headers: @auth_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "POST com media_file só com espaço no formulário retorna 400, não 500 (CR-01)" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: " "),
           headers: @multipart_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "POST com media_file false em JSON retorna 400, não 500 (CR-01)" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: false).to_json,
           headers: @auth_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "POST com media_file como lista retorna 400 (CR-01)" do
    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: [ "abc" ]),
           headers: @multipart_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "POST com signed id de blob existente retorna 400 e não anexa o blob (T-33-01)" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io:           file_fixture("sample.jpg").open,
      filename:     "sample.jpg",
      content_type: "image/jpeg"
    )

    assert_rejected_without_effects do
      post "/api/v1/ai/artes",
           params:  multipart_params(media_file: blob.signed_id).to_json,
           headers: @auth_headers
    end

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
    assert_equal 0, ActiveStorage::Attachment.where(blob_id: blob.id).count
  end

  test "POST multipart sem autenticação retorna 401 e não cria arte" do
    assert_no_difference "Arte.count" do
      post "/api/v1/ai/artes",
           params: multipart_params(media_file: fixture_file_upload("sample.jpg", "image/jpeg"))
    end

    assert_equal 401, response.status
  end

  test "POST multipart com client_id inexistente retorna 422 sem efeitos" do
    assert_no_difference [ "Arte.count", "ActiveStorage::Attachment.count" ] do
      post "/api/v1/ai/artes",
           params:  multipart_params(client_id: 0, media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
           headers: @multipart_headers
    end

    assert_equal 422, response.status
  end

  test "GET lista artes criadas por upload somente sob o client_id do próprio cliente (D-12)" do
    outro_cliente = Client.create!(name: "Outro Cliente Upload", password: "OutroUp123!", active: true)

    ids = [ @client, outro_cliente ].to_h do |cliente|
      post "/api/v1/ai/artes",
           params:  multipart_params(client_id: cliente.id, media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
           headers: @multipart_headers
      assert_equal 201, response.status
      [ cliente, response.parsed_body.dig("data", "id") ]
    end
    Arte.where(id: ids.values).update_all(status: Arte.statuses[:approved])

    hoje = Date.current.to_s
    ids.each do |cliente, arte_id|
      get "/api/v1/ai/artes?from=#{hoje}&to=#{hoje}&client_id=#{cliente.id}", headers: @auth_headers

      assert_equal 200, response.status
      data = response.parsed_body["data"]
      assert_equal [ arte_id ], data.map { |a| a["id"] }
      assert_equal "upload", data.first["media_source_type"]
      assert data.first["media_url"].present?
    end
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

  private

  # Rejeição sem nenhum efeito: nem Arte, Blob, Attachment nem job. Sempre a forma de bloco
  # de assert_no_enqueued_jobs (lição CR-02 da fase 32).
  def assert_rejected_without_effects(&block)
    assert_no_difference [ "Arte.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      assert_no_enqueued_jobs(&block)
    end
  end

  def multipart_params(extra = {})
    {
      title:        "Arte IA multipart",
      scheduled_on: Date.current.to_s,
      platform:     "instagram",
      media_type:   "image",
      client_id:    @client.id
    }.merge(extra)
  end
end
