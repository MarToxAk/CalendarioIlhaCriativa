require "test_helper"

class Admin::DivulgacoesControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin_divulgacoes@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "Divulgacoes Controller Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    @g1 = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo Um",  active: true, synced_at: Time.current)
    @g2 = @instance.whatsapp_groups.create!(remote_jid: "g2@g.us", subject: "Grupo Dois", active: true, synced_at: Time.current)

    @arte = @client.artes.new(
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      status:       :approved,
      title:        "Arte Aprovada"
    )
    @arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    @arte.save!
  end

  # --- happy path (Task 2 / DIVU-01, DIVU-09) ---------------------------

  test "POST create agenda uma divulgacao com uma linha pendente por grupo e redireciona pro show" do
    assert_difference("Divulgacao.count", 1) do
      assert_difference("DivulgacaoGrupo.count", 2) do
        post admin_client_divulgacoes_path(@client), params: {
          divulgacao: {
            arte_id:            @arte.id,
            whatsapp_group_ids: [ @g1.id, @g2.id ],
            scheduled_for:      3.days.from_now.strftime("%Y-%m-%dT%H:%M")
          }
        }
      end
    end

    divulgacao = Divulgacao.last
    assert_redirected_to admin_client_divulgacao_path(@client, divulgacao)
    assert_equal @client.id, divulgacao.client_id
    assert_equal @arte.id,   divulgacao.arte_id
    assert_equal "agendada", divulgacao.status
    assert_equal [ "pendente" ], divulgacao.divulgacao_grupos.pluck(:status).uniq
    assert_equal [ "Grupo Dois", "Grupo Um" ], divulgacao.divulgacao_grupos.pluck(:group_name).sort
    assert_equal [ "g1@g.us", "g2@g.us" ], divulgacao.divulgacao_grupos.pluck(:remote_jid).sort
  end

  # --- motor de envio (fase 29-01, ENVIO-01) ----------------------------

  test "POST create enfileira Divulgacoes::DispatchJob agendado para scheduled_for" do
    param     = 3.days.from_now.strftime("%Y-%m-%dT%H:%M")
    scheduled = Time.zone.parse(param)

    assert_enqueued_with(job: Divulgacoes::DispatchJob, at: scheduled) do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: {
          arte_id:            @arte.id,
          whatsapp_group_ids: [ @g1.id ],
          scheduled_for:      param
        }
      }
    end
  end

  # --- cross-client isolation A×B (Task 3 / SEG-01, SEG-02) -------------

  # Constroi o cliente B com sua propria instancia + grupo + arte aprovada. O
  # segredo de B tem strings distintas para o refute_includes provar que a
  # re-renderizacao do form de A nao vaza nada de B.
  def build_client_b
    client_b = Client.create!(name: "Divulgacoes Cliente B", password: "senha1234", password_confirmation: "senha1234")
    instance_b = client_b.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client_b),
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    group_b = instance_b.whatsapp_groups.create!(remote_jid: "segredo-b@g.us", subject: "Segredo do B", active: true, synced_at: Time.current)
    arte_b = client_b.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte Secreta do B")
    arte_b.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_b.save!
    [ client_b, group_b, arte_b ]
  end

  test "arte de OUTRO cliente pela URL de divulgacoes do cliente A -- re-render :new, zero linhas, sem vazar dados de B" do
    _client_b, group_b, arte_b = build_client_b

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_b.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    refute_includes response.body, arte_b.title
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid
  end

  test "id de grupo de OUTRO cliente no array pela URL de A -- re-render :new, zero linhas, sem vazar dados de B" do
    _client_b, group_b, _arte_b = build_client_b

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id, group_b.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid
  end

  test "id de grupo INATIVO do proprio cliente A -- re-render :new, zero linhas, flash Selecao invalida" do
    inactive = @instance.whatsapp_groups.create!(remote_jid: "inativo-a@g.us", subject: "Grupo Inativo A", active: false, synced_at: Time.current)

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id, inactive.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Seleção inválida", flash[:alert]
  end

  test "nenhum grupo marcado (chave ausente) -- re-render :new, zero linhas, mensagem selecione ao menos um grupo" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Selecione ao menos um grupo"
  end

  # --- CR-02 (28-REVIEW): param shapes malformados nao podem estourar 500 -----

  test "CR-02: whatsapp_group_ids Hash-shaped (em vez de Array) -- 422 tratado, nunca 500" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: { "foo" => "1" }, scheduled_for: future_param }
      }
    end

    # strong params descarta o Hash (permit de array so aceita Array) -> gids
    # vira [] -> cai na validacao normal "ao menos um grupo", nao no rescue.
    assert_response :unprocessable_entity
    assert_includes response.body, "Selecione ao menos um grupo"
  end

  test "CR-02: arte_id Array-shaped (em vez de escalar) -- 422 tratado via rescue RecordNotFound, nunca 500" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: [ @arte.id.to_s, @arte.id.to_s ], whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    # strong params descarta o Array (permit escalar so aceita tipos escalares)
    # -> arte_id vira nil -> .find(nil) levanta RecordNotFound -> rescue.
    assert_response :unprocessable_entity
    assert_match "Seleção inválida", flash[:alert]
  end

  # --- WR-01 (28-REVIEW): rescue RecordNotFound preserva o que ja resolvia ----

  test "WR-01: rescue RecordNotFound preserva scheduled_for bruto e os grupos que ainda resolvem" do
    _client_b, group_b, _arte_b = build_client_b

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id, group_b.id ], scheduled_for: "2026-09-20T15:30" }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Seleção inválida", flash[:alert]
    # scheduled_for bruto sobrevive ao re-render (antes do fix: form em branco)
    assert_includes response.body, "2026-09-20T15:30"
    # @g1 (valido, do proprio cliente) continua marcado; group_b (de outro
    # cliente, causou o RecordNotFound) nao aparece de jeito nenhum na resposta.
    assert_select "input[type=checkbox][name='divulgacao[whatsapp_group_ids][]'][value='#{@g1.id}'][checked]"
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid
  end

  test "WR-01 (residual): rescue RecordNotFound preserva a arte selecionada quando so o grupo falha em resolver" do
    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ 999_999 ], scheduled_for: "2026-09-20T15:30" }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Seleção inválida", flash[:alert]
    # a arte, ja resolvida com sucesso antes do RecordNotFound do grupo, precisa
    # continuar SELECIONADA no <select> re-renderizado -- nao basta listar como
    # <option>, o admin nao deveria ter que re-escolher uma arte que ja era valida.
    assert_select "select[name='divulgacao[arte_id]'] option[value='#{@arte.id}'][selected]"
  end

  # --- Task 2: datetime-local -> Time.zone round-trip (DIVU-05) --------

  test "scheduled_for cru 2026-09-15T14:00 round-trips pra Time.zone.local Brasilia (-03:00)" do
    assert_difference("Divulgacao.count", 1) do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "2026-09-15T14:00" }
      }
    end

    d = Divulgacao.last
    assert_equal Time.zone.local(2026, 9, 15, 14, 0), d.scheduled_for
    assert_equal(-3 * 3600, d.scheduled_for.utc_offset)
  end

  test "criar a divulgacao nao transforma Arte#scheduled_on num datetime — continua Date sem hora" do
    post admin_client_divulgacoes_path(@client), params: {
      divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "2026-09-15T14:00" }
    }
    assert_redirected_to admin_client_divulgacao_path(@client, Divulgacao.last)

    @arte.reload
    assert_kind_of Date, @arte.scheduled_on
    assert_not @arte.scheduled_on.respond_to?(:hour)
  end

  test "scheduled_for com lixo impossivel de parsear casta pra nil e cai no presence — sem 500" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "not-a-date" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Informe a data e hora do envio."
  end

  # --- DIVU-09 snapshot congelado -------------------------------------

  test "renomear e desativar o grupo apos criar nao altera o snapshot group_name/remote_jid" do
    original_name = @g1.display_name
    divulgacao = @client.divulgacoes.create!(
      arte:          @arte,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g1, group_name: @g1.display_name, remote_jid: @g1.remote_jid) ]
    )
    dg = divulgacao.divulgacao_grupos.first

    @g1.update!(subject: "Nome totalmente novo do grupo")
    @g1.update!(active: false)
    dg.reload

    assert_equal original_name, dg.group_name
    assert_equal "g1@g.us", dg.remote_jid
  end

  # --- Task 3: cada mensagem de validacao chega pela caixa errors[:base] ---

  def future_param = 3.days.from_now.strftime("%Y-%m-%dT%H:%M")

  test "arte pending -> re-render :new com 'A arte selecionada nao esta aprovada.' (DIVU-02)" do
    arte_pending = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :pending, title: "Arte Pendente"
    )
    arte_pending.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_pending.save!

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_pending.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  test "arte com external_url (sem arquivo) -> 'Esta arte usa um link externo.' (DIVU-03)" do
    arte_link = @client.artes.create!(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte com Link", external_url: "https://drive.google.com/file/x"
    )

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_link.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação."
  end

  test "arquivo acima do teto de 16 MB -> mensagem com tamanho atual e limite (DIVU-04)" do
    arte_grande = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte Grande"
    )
    arte_grande.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_grande.save!
    arte_grande.media_file.blob.update_column(:byte_size, 20.megabytes)

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_grande.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "20 MB"
    assert_includes response.body, "16 MB"
    assert_includes response.body, "Comprima ou reenvie um arquivo menor na arte."
  end

  test "arte caption_only aprovada + grupo valido + futuro -> cria a divulgacao (DIVU-03, caption_only IN escopo)" do
    arte_texto = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :caption_only,
      status: :approved, title: "Arte Só Texto", caption: "Bom dia a todos!"
    )
    arte_texto.save!(validate: false) # media_source_present da Arte exige arquivo/link; caption_only e escopo da Divulgacao

    assert_difference("Divulgacao.count", 1) do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_texto.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_redirected_to admin_client_divulgacao_path(@client, Divulgacao.last)
  end

  test "scheduled_for no passado -> 'A data e hora do envio precisam estar no futuro.'" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: 1.hour.ago.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "A data e hora do envio precisam estar no futuro."
  end

  test "SEG-02 backstop no nivel do model: arte do cliente B + divulgacao do cliente A e invalida" do
    _client_b, _group_b, arte_b = build_client_b

    d = @client.divulgacoes.new(
      arte:          arte_b,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g1, group_name: @g1.display_name, remote_jid: @g1.remote_jid) ]
    )

    assert_not d.valid?
    assert_includes d.errors[:base], "A arte e os grupos precisam ser do mesmo cliente."
  end

  # --- Task 1: #new renderiza a prévia real + placeholder (DIVU-06) ------

  test "GET new renderiza a prévia com a mídia real pelo proxy path, a legenda verbatim e o placeholder" do
    @arte.update!(caption: "Promoção imperdível!\nSó hoje até as 18h.")

    arte_texto = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :caption_only,
      status: :approved, title: "Arte Só Texto", caption: "Mensagem de texto pura."
    )
    arte_texto.save!(validate: false)

    get new_admin_client_divulgacao_path(@client)

    assert_response :success
    # mídia real streamada pela rota proxy auth-gated (não url_for / rails_blob_path / presign)
    assert_includes response.body, "/rails/active_storage/blobs/proxy"
    assert_no_match %r{/rails/active_storage/blobs/redirect}, response.body
    # legenda verbatim da arte com imagem
    assert_includes response.body, "Promoção imperdível!"
    # arte caption_only -> marcador de texto no lugar da mídia
    assert_includes response.body, "(sem mídia — mensagem de texto)"
    # placeholder e header da prévia
    assert_includes response.body, "Selecione uma arte para ver a prévia."
    assert_includes response.body, "Prévia — é exatamente isto que vai ao grupo"
    assert_includes response.body, "Legenda (enviada sem alteração):"
  end

  test "GET new: uma legenda com <script> aparece escapada (auto-escape do ERB), nunca inerte no DOM" do
    @arte.update!(caption: "<script>alert('xss')</script> confira já")

    get new_admin_client_divulgacao_path(@client)

    assert_response :success
    assert_includes response.body, "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    assert_no_match %r{<script>alert\('xss'\)</script>}, response.body
  end

  # --- Task 2: estimativa de duração no #new (DIVU-07) ------------------

  test "GET new: o span da estimativa renderiza com o zero-state '—' e carrega min/max value" do
    get new_admin_client_divulgacao_path(@client)

    assert_response :success
    assert_match %r{<span data-divulgacao-estimate-target="text">\s*—\s*</span>}, response.body
    assert_includes response.body, %(data-divulgacao-estimate-min-value="25")
    assert_includes response.body, %(data-divulgacao-estimate-max-value="45")
    assert_includes response.body, "Estimativa de duração"
    assert_includes response.body, "Tempo aproximado do disparo, do primeiro ao último grupo."
  end

  # --- Task 3: fiação ponta a ponta dos três controllers no #new --------

  test "GET new (2 artes aprovadas + 3 grupos): um pane por arte, placeholder, estimativa, marcadores do picker, min/max e ordem dos campos" do
    arte_texto = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :caption_only,
      status: :approved, title: "Arte Só Texto 2", caption: "Texto puro."
    )
    arte_texto.save!(validate: false)
    @instance.whatsapp_groups.create!(remote_jid: "g3@g.us", subject: "Grupo Três", active: true, synced_at: Time.current)

    get new_admin_client_divulgacao_path(@client)
    assert_response :success

    b = response.body
    panes = b.scan('data-divulgacao-preview-target="pane"').size
    assert_equal @client.artes.approved.count, panes
    assert_equal 2, panes
    assert_includes b, %(data-arte-id="#{@arte.id}")
    assert_includes b, %(data-arte-id="#{arte_texto.id}")

    assert_includes b, "Selecione uma arte para ver a prévia."
    assert_match %r{<span data-divulgacao-estimate-target="text">\s*—\s*</span>}, b
    assert_includes b, "data-picker-select-all"
    assert_includes b, "data-picker-counter"
    assert_includes b, %(data-divulgacao-estimate-min-value="25")
    assert_includes b, %(data-divulgacao-estimate-max-value="45")

    # os três controllers, uma vez cada, na fiação esperada. O data-action do
    # <select> de arte vem do hash data: do collection_select — o Rails escapa o
    # "->" para "-&gt;" no HTML serializado (o browser decodifica de volta ao
    # ler getAttribute, então o Stimulus funciona); asserimos sem o prefixo.
    assert_includes b, "divulgacao-preview#show"
    assert_includes b, "change->divulgacao-estimate#recompute change->picker#refresh"
    assert_equal 1, b.scan('data-controller="picker"').size
    assert_equal 1, b.scan('data-controller="divulgacao-estimate"').size

    # ordem dos campos: arte select → picker → datetime → estimativa → preview
    assert_operator b.index('name="divulgacao[arte_id]"'), :<, b.index("data-picker-select-all")
    assert_operator b.index("data-picker-select-all"), :<, b.index('name="divulgacao[scheduled_for]"')
    assert_operator b.index('name="divulgacao[scheduled_for]"'), :<, b.index('data-divulgacao-estimate-target="text"')
    assert_operator b.index('data-divulgacao-estimate-target="text"'), :<, b.index("Prévia — é exatamente isto que vai ao grupo")
  end

  test "GET new (exatamente 1 arte aprovada): o único pane renderiza e a página não quebra" do
    assert_equal 1, @client.artes.approved.count

    get new_admin_client_divulgacao_path(@client)
    assert_response :success

    assert_equal 1, response.body.scan('data-divulgacao-preview-target="pane"').size
    assert_includes response.body, %(data-arte-id="#{@arte.id}")
  end

  # --- Task 1: #new guards + estados vazios/bloqueados + index completo ---

  test "GET new sem whatsapp_instance -- empty state, sem <form" do
    client_sem_instancia = Client.create!(name: "Sem Instancia", password: "senha1234", password_confirmation: "senha1234")

    get new_admin_client_divulgacao_path(client_sem_instancia)

    assert_response :success
    assert_includes response.body, "Nenhuma instância de WhatsApp"
    # A layout tem seu proprio <form> de logout — o marcador real de "form de
    # divulgacao NAO renderizado" e a ausencia do campo arte_id.
    assert_no_match(/name="divulgacao\[arte_id\]"/, response.body)
  end

  test "GET new com instancia disconnected -- banner amber + submit disabled, form ainda renderiza" do
    @instance.update!(connection_state: :disconnected)

    get new_admin_client_divulgacao_path(@client)

    assert_response :success
    assert_includes response.body, "A instância de WhatsApp deste cliente está desconectada. Reconecte o número antes de agendar uma divulgação."
    assert_match(/<form/, response.body)
    assert_match(/<input[^>]*type="submit"[^>]*disabled/, response.body)
  end

  test "GET new sem arte aprovada -- empty state, sem <form" do
    @arte.update!(status: :pending)

    get new_admin_client_divulgacao_path(@client)

    assert_response :success
    assert_includes response.body, "Nenhuma arte aprovada"
    assert_no_match(/name="divulgacao\[arte_id\]"/, response.body)
  end

  test "POST create sem whatsapp_instance -- re-render :new 422, zero linhas" do
    client_sem_instancia = Client.create!(name: "Sem Instancia Create", password: "senha1234", password_confirmation: "senha1234")
    arte = client_sem_instancia.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :caption_only, status: :approved, title: "Arte X", caption: "Oi")
    arte.save!(validate: false)

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(client_sem_instancia), params: {
        divulgacao: { arte_id: arte.id, scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Nenhuma instância de WhatsApp"
  end

  test "GET index vazio -- empty state com Nova divulgacao" do
    client_vazio = Client.create!(name: "Sem Divulgacoes", password: "senha1234", password_confirmation: "senha1234")

    get admin_client_divulgacoes_path(client_vazio)

    assert_response :success
    assert_includes response.body, "Nenhuma divulgação agendada"
  end

  test "GET index com 2 registros -- table + 2 links Ver + datetime com (BRT)" do
    d1 = @client.divulgacoes.create!(
      arte: @arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g1, group_name: @g1.display_name, remote_jid: @g1.remote_jid) ]
    )
    d2 = @client.divulgacoes.create!(
      arte: @arte, scheduled_for: 4.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g2, group_name: @g2.display_name, remote_jid: @g2.remote_jid) ]
    )

    get admin_client_divulgacoes_path(@client)

    assert_response :success
    assert_match(/<table/, response.body)
    assert_equal 2, response.body.scan(">Ver<").size
    assert_includes response.body, "(BRT)"
    [ d1, d2 ].each { |d| assert_includes response.body, admin_client_divulgacao_path(@client, d) }
  end

  # --- Task 2: #show + #cancel + Divulgacao#cancelar! ---------------------

  def build_divulgacao_agendada(client: @client, arte: @arte, groups: [ @g1, @g2 ])
    client.divulgacoes.create!(
      arte: arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: groups.map { |g| DivulgacaoGrupo.new(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid) }
    )
  end

  test "GET show de divulgacao agendada -- tres secoes, (BRT), grupos pendente pill, botao cancelar" do
    d = build_divulgacao_agendada

    get admin_client_divulgacao_path(@client, d)

    assert_response :success
    assert_includes response.body, "Detalhes"
    assert_includes response.body, "Grupos (2)"
    assert_includes response.body, "Prévia"
    assert_includes response.body, "(BRT)"
    assert_includes response.body, "Grupo Um"
    assert_includes response.body, "Grupo Dois"
    assert_equal 2, response.body.scan("Pendente").size
    assert_includes response.body, "Cancelar divulgação"
  end

  test "GET show de divulgacao cancelada -- banner neutro, pill vermelha Cancelada, sem botao cancelar, grupos preservados" do
    d = build_divulgacao_agendada
    d.cancelar!

    get admin_client_divulgacao_path(@client, d)

    assert_response :success
    assert_includes response.body, "Esta divulgação foi cancelada em"
    assert_includes response.body, "Nenhum envio será feito."
    assert_includes response.body, "Cancelada"
    assert_includes response.body, "text-[#EE3537]" # pill vermelha, nao a cor de acao
    assert_no_match(/Cancelar divulgação/, response.body)
    assert_includes response.body, "Grupo Um"
    assert_includes response.body, "Grupo Dois"
  end

  test "PATCH cancel numa divulgacao agendada -- flipa pra cancelada, preserva registro/grupos, notice" do
    d = build_divulgacao_agendada

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      patch cancel_admin_client_divulgacao_path(@client, d)
    end

    assert_redirected_to admin_client_divulgacao_path(@client, d)
    assert_equal "Divulgação cancelada. Nenhum envio será feito.", flash[:notice]
    assert_equal "cancelada", d.reload.status
    assert_equal 2, d.divulgacao_grupos.count
  end

  test "PATCH cancel numa divulgacao ja cancelada -- no-op, alert de guarda" do
    d = build_divulgacao_agendada
    d.cancelar!

    assert_no_difference "Divulgacao.count" do
      patch cancel_admin_client_divulgacao_path(@client, d)
    end

    assert_redirected_to admin_client_divulgacao_path(@client, d)
    assert_equal "Só é possível cancelar uma divulgação ainda agendada.", flash[:alert]
    assert_equal "cancelada", d.reload.status
  end

  test "GET show / PATCH cancel de divulgacao de OUTRO cliente -- 404, nada vaza no corpo" do
    _client_b, group_b, arte_b = build_client_b
    d_b = build_divulgacao_agendada(client: _client_b, arte: arte_b, groups: [ group_b ])

    get admin_client_divulgacao_path(@client, d_b)
    assert_response :not_found
    refute_includes response.body, arte_b.title
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid

    patch cancel_admin_client_divulgacao_path(@client, d_b)
    assert_response :not_found

    d_b.reload
    assert_equal "agendada", d_b.status
  end

  test "GET show de divulgacao com zero divulgacao_grupos -- Grupos (0), sem erro (backstop)" do
    d = @client.divulgacoes.new(arte: @arte, scheduled_for: 3.days.from_now)
    d.save!(validate: false) # ao_menos_um_grupo bloquearia via form -- so alcancavel via console/backstop

    get admin_client_divulgacao_path(@client, d)

    assert_response :success
    assert_includes response.body, "Grupos (0)"
    assert_includes response.body, "Nenhum grupo."
  end

  test "nao existe rota destroy para divulgacoes" do
    d = build_divulgacao_agendada

    delete admin_client_divulgacao_path(@client, d)
    assert_response :not_found
    assert_not_nil Divulgacao.find_by(id: d.id)
  end
end
