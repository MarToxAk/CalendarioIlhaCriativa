# frozen_string_literal: true

require "test_helper"

# POST /api/v1/ai/divulgacoes — fase 32 (agendamento de Divulgacao pela IA).
#
# O teto de 16MB e as demais regras de negocio ja tem teste no model
# (test/models/divulgacao_test.rb, fase 28); aqui so se prova que as regras
# existentes chegam como 422 e que o escopo por cliente (D-09) nunca vaza.
class Api::V1::Ai::DivulgacoesControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  D10_KEYS   = %w[arte_id client_id created_at grupos id scheduled_for status updated_at].freeze
  GRUPO_KEYS = %w[error_code group_name remote_jid sent_at status].freeze

  setup do
    @original_ai_key = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @auth_headers = {
      "Authorization" => "Bearer #{AI_API_KEY}",
      "Content-Type"  => "application/json"
    }

    # Cliente A: instancia conectada, 2 grupos ativos, 1 inativo e arte aprovada com arquivo.
    @client = Client.create!(name: "Cliente AI Divulgacao A", password: "SenhaIA123!", active: true)
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected, groups_synced_at: Time.current
    )
    @g1 = @instance.whatsapp_groups.create!(remote_jid: "ai-g1@g.us", subject: "Grupo Um", active: true, synced_at: Time.current)
    @g2 = @instance.whatsapp_groups.create!(remote_jid: "ai-g2@g.us", subject: "Grupo Dois", active: true, synced_at: Time.current)
    @g_inativo = @instance.whatsapp_groups.create!(remote_jid: "ai-gx@g.us", subject: "Grupo Inativo", active: false, synced_at: Time.current)
    @arte = build_arte_with_file!(@client, title: "Arte Aprovada A")

    # Cliente B: o "outro cliente" dos casos de escopo.
    @client_b = Client.create!(name: "Cliente AI Divulgacao B", password: "SenhaIA123!", active: true)
    @instance_b = @client_b.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client_b),
      connection_state: :connected, groups_synced_at: Time.current
    )
    @gb = @instance_b.whatsapp_groups.create!(remote_jid: "ai-gb@g.us", subject: "Grupo B", active: true, synced_at: Time.current)
    @arte_b = build_arte_with_file!(@client_b, title: "Arte Aprovada B")

    @scheduled = 3.days.from_now.change(usec: 0)
  end

  teardown do
    ENV["AI_API_KEY"] = @original_ai_key
  end

  # --- autenticacao ---------------------------------------------------------

  test "POST create sem Bearer retorna 401 unauthorized" do
    # Forma de bloco: o setup anexa arquivos (Active Storage enfileira AnalyzeJob),
    # entao um assert_no_enqueued_jobs sem bloco contaria jobs que nao sao do request.
    assert_no_enqueued_jobs do
      assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
        post_divulgacao(valid_body, headers: { "Content-Type" => "application/json" })
      end
    end
    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
  end

  # --- caminho feliz ----------------------------------------------------------

  test "POST create agenda de verdade: 201, DispatchJob em scheduled_for e uma linha pendente por grupo" do
    assert_enqueued_with(job: Divulgacoes::DispatchJob, at: @scheduled) do
      assert_difference [ "Divulgacao.count" ], 1 do
        assert_difference [ "DivulgacaoGrupo.count" ], 2 do
          post_divulgacao(valid_body)
        end
      end
    end

    assert_equal 201, response.status
    body = response.parsed_body
    data = body["data"]
    assert_equal [], body["errors"]
    assert_equal "agendada", data["status"]
    assert_equal @client.id, data["client_id"]
    assert_equal @arte.id, data["arte_id"]
    assert_equal D10_KEYS, data.keys.sort
    assert_equal 2, data["grupos"].size
    data["grupos"].each do |g|
      assert_equal GRUPO_KEYS, g.keys.sort
      assert_equal "pendente", g["status"]
    end
    assert_equal [ "ai-g1@g.us", "ai-g2@g.us" ], data["grupos"].map { |g| g["remote_jid"] }.sort
    assert_equal [ "Grupo Dois", "Grupo Um" ], data["grupos"].map { |g| g["group_name"] }.sort
  end

  test "POST create com scheduled_for em UTC persiste o mesmo instante do offset -03:00" do
    utc_body = valid_body(scheduled_for: @scheduled.utc.iso8601)
    offset_body = valid_body(scheduled_for: @scheduled.in_time_zone("America/Sao_Paulo").iso8601)

    post_divulgacao(utc_body)
    assert_equal 201, response.status
    utc_instant = Divulgacao.find(response.parsed_body.dig("data", "id")).scheduled_for

    post_divulgacao(offset_body)
    assert_equal 201, response.status
    offset_instant = Divulgacao.find(response.parsed_body.dig("data", "id")).scheduled_for

    assert_equal @scheduled, utc_instant
    assert_equal utc_instant, offset_instant
  end

  test "POST create ignora status forcado no payload e nasce agendada" do
    post_divulgacao(valid_body(status: "concluida"))

    assert_equal 201, response.status
    assert_equal "agendada", response.parsed_body.dig("data", "status")
    assert Divulgacao.find(response.parsed_body.dig("data", "id")).status_agendada?
  end

  # --- 400: ids obrigatorios ausentes/malformados -----------------------------

  test "POST create sem client_id retorna 400 bad_request" do
    assert_bad_request valid_body.except(:client_id)
  end

  test "POST create sem arte_id retorna 400 bad_request" do
    assert_bad_request valid_body.except(:arte_id)
  end

  test "POST create com arte_id como Array retorna 400 e nunca 500" do
    assert_bad_request valid_body(arte_id: [ @arte.id ])
  end

  test "POST create com id malformado em whatsapp_group_ids retorna 400 e nao agenda para os demais" do
    assert_bad_request valid_body(whatsapp_group_ids: [ "abc", @g1.id ])
    assert_equal "whatsapp_group_ids deve conter apenas ids numéricos.", response.parsed_body.dig("errors", 0, "detail")
  end

  test "POST create com id parcialmente numerico em whatsapp_group_ids retorna 400" do
    assert_bad_request valid_body(whatsapp_group_ids: [ "#{@g1.id}abc" ])
  end

  # --- 404: inexistente e escopo (D-09) ----------------------------------------

  test "POST create com client_id inexistente retorna 404 not_found" do
    assert_not_found valid_body(client_id: 0)
  end

  # --- 422: validacoes existentes do model (D-08) ---------------------------------

  test "POST create com whatsapp_group_ids vazio retorna 422 pedindo ao menos um grupo" do
    assert_unprocessable valid_body(whatsapp_group_ids: []), detail: "ao menos um grupo"
  end

  test "POST create sem whatsapp_group_ids retorna 422 pedindo ao menos um grupo" do
    assert_unprocessable valid_body.except(:whatsapp_group_ids), detail: "ao menos um grupo"
  end

  test "POST create com whatsapp_group_ids como Hash retorna 422 e nunca 500" do
    assert_unprocessable valid_body(whatsapp_group_ids: { "0" => @g1.id })
  end

  test "POST create com arte nao aprovada retorna 422" do
    pendente = build_arte_with_file!(@client, title: "Arte Pendente", status: :pending)
    assert_unprocessable valid_body(arte_id: pendente.id), detail: "aprovada"
  end

  test "POST create com arte aprovada que usa link externo retorna 422" do
    com_link = Arte.create!(
      client: @client, scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte com Link", external_url: "https://example.com/arte.jpg"
    )
    assert_unprocessable valid_body(arte_id: com_link.id), detail: "link externo"
  end

  test "POST create com scheduled_for no passado retorna 422" do
    assert_unprocessable valid_body(scheduled_for: 1.day.ago.iso8601), detail: "futuro"
  end

  test "POST create com scheduled_for ilegivel retorna 422 e nao 400" do
    assert_unprocessable valid_body(scheduled_for: "lixo"), detail: "data e hora"
  end

  test "POST create sem scheduled_for retorna 422" do
    assert_unprocessable valid_body.except(:scheduled_for)
  end

  # --- escopo cross-client (D-09, T-32-01/T-32-05) ----------------------------------

  test "POST create com arte de outro cliente retorna 404 generico e nada e gravado" do
    assert_not_found valid_body(arte_id: @arte_b.id)
  end

  test "POST create com grupo de outro cliente retorna 404 generico e nada e gravado" do
    assert_not_found valid_body(whatsapp_group_ids: [ @g1.id, @gb.id ])
  end

  test "POST create com grupo inativo do proprio cliente retorna 404 generico e nada e gravado" do
    assert_not_found valid_body(whatsapp_group_ids: [ @g1.id, @g_inativo.id ])
  end

  # --- GET index (fase 32-02: D-03, D-10..D-13) -------------------------------------

  test "GET index sem Bearer retorna 401 unauthorized" do
    get "/api/v1/ai/divulgacoes", params: { client_id: @client.id }
    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index sem client_id retorna 400 bad_request e nunca lista entre clientes" do
    make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)
    get_index
    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index com client_id inexistente retorna 404 not_found" do
    get_index(client_id: 0)
    assert_equal 404, response.status
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index com client_id em formato Hash retorna 400 e nunca 500" do
    get "/api/v1/ai/divulgacoes?client_id[x]=1", headers: @auth_headers
    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index lista so as divulgacoes do cliente, com os grupos de cada uma" do
    d1 = make_divulgacao(client: @client, arte: @arte, groups: [ @g1, @g2 ], at: index_day.change(hour: 9))
    d_b = make_divulgacao(client: @client_b, arte: @arte_b, groups: [ @gb ], at: index_day.change(hour: 10))

    get_index(client_id: @client.id)

    assert_equal 200, response.status
    data = response.parsed_body["data"]
    assert_equal [ d1.id ], data.map { |d| d["id"] }
    assert_not_includes data.map { |d| d["id"] }, d_b.id
    assert_equal D10_KEYS, data.first.keys.sort
    assert_equal 2, data.first["grupos"].size
    data.first["grupos"].each { |g| assert_equal GRUPO_KEYS, g.keys.sort }
  end

  test "GET index ordena por scheduled_for crescente" do
    tarde = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 18))
    cedo = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 8))
    depois = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day(1).change(hour: 8))

    get_index(client_id: @client.id)

    assert_equal [ cedo.id, tarde.id, depois.id ], response.parsed_body["data"].map { |d| d["id"] }
  end

  test "GET index filtra por status" do
    agendada = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)
    make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day, status: :cancelada)

    get_index(client_id: @client.id, status: "agendada")

    assert_equal 200, response.status
    assert_equal [ agendada.id ], response.parsed_body["data"].map { |d| d["id"] }
  end

  test "GET index com status invalido retorna 400 e nao uma lista vazia" do
    make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)

    get_index(client_id: @client.id, status: "bogus")

    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
    assert_includes response.parsed_body.dig("errors", 0, "detail"), "agendada"
  end

  test "GET index com from e to inclui o dia inteiro de to (23:30) e exclui o dia anterior a to" do
    cedo = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 9))
    noite = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 23, min: 30))
    make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day(2).change(hour: 12))
    dia = index_day.to_date

    get_index(client_id: @client.id, from: dia.to_s, to: dia.to_s)
    assert_equal 200, response.status
    assert_equal [ cedo.id, noite.id ], response.parsed_body["data"].map { |d| d["id"] }

    get_index(client_id: @client.id, to: (dia - 1).to_s)
    assert_equal 200, response.status
    assert_equal [], response.parsed_body["data"]
  end

  test "GET index aceita so from ou so to" do
    d1 = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 9))
    d3 = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day(2).change(hour: 12))
    dia = index_day.to_date

    get_index(client_id: @client.id, from: (dia + 1).to_s)
    assert_equal 200, response.status
    assert_equal [ d3.id ], response.parsed_body["data"].map { |d| d["id"] }

    get_index(client_id: @client.id, to: dia.to_s)
    assert_equal 200, response.status
    assert_equal [ d1.id ], response.parsed_body["data"].map { |d| d["id"] }
  end

  test "GET index com from maior que to retorna 400" do
    dia = index_day.to_date
    get_index(client_id: @client.id, from: (dia + 1).to_s, to: dia.to_s)
    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index com data ilegivel retorna 400" do
    get_index(client_id: @client.id, from: "nao-e-data")
    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET index pagina com meta e limita per_page a 100" do
    3.times { |i| make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 8 + i)) }

    get_index(client_id: @client.id, per_page: 2)
    assert_equal 200, response.status
    assert_equal 2, response.parsed_body["data"].size
    pagination = response.parsed_body.dig("meta", "pagination")
    assert_equal 3, pagination["total_count"]
    assert_equal 2, pagination["total_pages"]
    assert_equal 2, pagination["per_page"]

    get_index(client_id: @client.id, per_page: 500)
    assert_equal 100, response.parsed_body.dig("meta", "pagination", "per_page")
  end

  test "GET index com pagina fora do intervalo retorna 404 page_out_of_range" do
    3.times { |i| make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day.change(hour: 8 + i)) }

    get_index(client_id: @client.id, per_page: 2, page: 3)

    assert_equal 404, response.status
    assert_equal "page_out_of_range", response.parsed_body.dig("errors", 0, "code")
  end

  # --- GET show -----------------------------------------------------------------------

  test "GET show sem Bearer retorna 401 unauthorized" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)
    get "/api/v1/ai/divulgacoes/#{d.id}"
    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
  end

  test "GET show devolve a divulgacao com o resumo por grupo" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1, @g2 ], at: index_day)

    get "/api/v1/ai/divulgacoes/#{d.id}", headers: @auth_headers

    assert_equal 200, response.status
    data = response.parsed_body["data"]
    assert_equal d.id, data["id"]
    assert_equal D10_KEYS, data.keys.sort
    assert_equal 2, data["grupos"].size
    data["grupos"].each do |g|
      assert_equal GRUPO_KEYS, g.keys.sort
      assert_equal "pendente", g["status"]
    end
  end

  test "GET show com id inexistente retorna 404 not_found" do
    get "/api/v1/ai/divulgacoes/0", headers: @auth_headers
    assert_equal 404, response.status
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  # --- POST cancel (D-04) -----------------------------------------------------------

  test "POST cancel sem Bearer retorna 401 e nao muda o status" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)
    post "/api/v1/ai/divulgacoes/#{d.id}/cancel"
    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
    assert d.reload.status_agendada?
  end

  test "POST cancel transforma agendada em cancelada sem enfileirar job" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)

    assert_no_enqueued_jobs do
      post_cancel(d)
    end

    assert_equal 200, response.status
    assert_equal "cancelada", response.parsed_body.dig("data", "status")
    assert d.reload.status_cancelada?
  end

  test "POST cancel e idempotente: segunda chamada responde 200 cancelada" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day)

    post_cancel(d)
    post_cancel(d)

    assert_equal 200, response.status
    assert_equal "cancelada", response.parsed_body.dig("data", "status")
    assert d.reload.status_cancelada?
  end

  test "POST cancel de divulgacao em_andamento responde 200 sem mudar o status" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day, status: :em_andamento)

    post_cancel(d)

    assert_equal 200, response.status
    assert_equal "em_andamento", response.parsed_body.dig("data", "status")
    assert d.reload.status_em_andamento?
  end

  test "POST cancel de divulgacao concluida responde 200 sem mudar o status" do
    d = make_divulgacao(client: @client, arte: @arte, groups: [ @g1 ], at: index_day, status: :concluida)

    post_cancel(d)

    assert_equal 200, response.status
    assert_equal "concluida", response.parsed_body.dig("data", "status")
    assert d.reload.status_concluida?
  end

  test "POST cancel com id inexistente retorna 404 not_found" do
    post "/api/v1/ai/divulgacoes/0/cancel", headers: @auth_headers
    assert_equal 404, response.status
    assert_equal "not_found", response.parsed_body.dig("errors", 0, "code")
  end

  private

  def valid_body(overrides = {})
    {
      client_id:          @client.id,
      arte_id:            @arte.id,
      whatsapp_group_ids: [ @g1.id, @g2.id ],
      scheduled_for:      @scheduled.iso8601
    }.merge(overrides)
  end

  def post_divulgacao(body, headers: @auth_headers)
    post "/api/v1/ai/divulgacoes", params: body.to_json, headers: headers
  end

  # Dia futuro (meia-noite no fuso do app) para o scheduled_for passar na validacao de criacao.
  # offset_days soma DIAS (aritmetica de Date): somar um inteiro a um TimeWithZone
  # adicionaria segundos, nao dias.
  def index_day(offset_days = 0)
    (Date.current + 10 + offset_days).in_time_zone
  end

  def get_index(params = {})
    get "/api/v1/ai/divulgacoes", params: params, headers: @auth_headers
  end

  def post_cancel(divulgacao)
    post "/api/v1/ai/divulgacoes/#{divulgacao.id}/cancel", headers: @auth_headers
  end

  # Cria a Divulgacao direto no model; status != agendada via update_columns (sem callbacks).
  def make_divulgacao(client:, arte:, groups:, at:, status: nil)
    divulgacao = client.divulgacoes.create!(
      arte: arte,
      scheduled_for: at,
      divulgacao_grupos: groups.map do |g|
        DivulgacaoGrupo.new(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid)
      end
    )
    divulgacao.update_columns(status: Divulgacao.statuses.fetch(status.to_s)) if status
    divulgacao
  end

  # Arte aprovada com arquivo anexado: a validacao da Divulgacao recusa arte com link externo.
  def build_arte_with_file!(client, title:, status: :approved)
    arte = client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image, status: status, title: title
    )
    arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte.save!
    arte
  end

  # Falhas nunca gravam linhas nem enfileiram job. Forma de bloco: o setup anexa
  # arquivos (Active Storage enfileira AnalyzeJob), que nao pode contar aqui.
  def assert_rejected_without_effects(body)
    assert_no_enqueued_jobs do
      assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
        post_divulgacao(body)
      end
    end
  end

  def assert_bad_request(body)
    assert_rejected_without_effects(body)
    assert_equal 400, response.status
    assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
  end

  # Mesmo corpo de erro para "nao existe" e "nao e seu": nunca revela de quem e o id.
  def assert_not_found(body)
    assert_rejected_without_effects(body)
    assert_equal 404, response.status
    error = response.parsed_body.dig("errors", 0)
    assert_equal "not_found", error["code"]
    assert_equal "Recurso não encontrado", error["detail"]
  end

  def assert_unprocessable(body, detail: nil)
    assert_rejected_without_effects(body)
    assert_equal 422, response.status
    errors = response.parsed_body["errors"]
    assert_not_empty errors
    assert_equal "validation_error", errors.first["code"]
    assert_equal "base", errors.first["field"]
    assert_includes errors.first["detail"].downcase, detail.downcase if detail
  end
end
