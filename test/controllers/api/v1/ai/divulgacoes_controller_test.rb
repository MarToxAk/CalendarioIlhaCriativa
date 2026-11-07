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
    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post_divulgacao(valid_body, headers: { "Content-Type" => "application/json" })
    end
    assert_equal 401, response.status
    assert_equal "unauthorized", response.parsed_body.dig("errors", 0, "code")
    assert_no_enqueued_jobs
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

  # Arte aprovada com arquivo anexado: a validacao da Divulgacao recusa arte com link externo.
  def build_arte_with_file!(client, title:, status: :approved)
    arte = client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image, status: status, title: title
    )
    arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte.save!
    arte
  end

  # Falhas nunca gravam linhas nem enfileiram job.
  def assert_rejected_without_effects(body)
    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post_divulgacao(body)
    end
    assert_no_enqueued_jobs
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
