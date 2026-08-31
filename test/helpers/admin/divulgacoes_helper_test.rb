require "test_helper"

class Admin::DivulgacoesHelperTest < ActionView::TestCase
  test "divulgacao_datetime_label(nil) retorna o travessao" do
    assert_equal "—", divulgacao_datetime_label(nil)
  end

  test "divulgacao_datetime_label('') retorna o travessao" do
    assert_equal "—", divulgacao_datetime_label("")
  end

  test "divulgacao_datetime_label formata DD/MM/AAAA HH:MM (BRT)" do
    t = Time.zone.local(2025, 9, 15, 14, 0)
    assert_equal "15/09/2025 14:00 (BRT)", divulgacao_datetime_label(t)
  end

  # --- divulgacao_duration_estimate (DIVU-07) ---------------------------

  test "divulgacao_duration_estimate(0) retorna o travessao (zero-state)" do
    assert_equal "—", divulgacao_duration_estimate(0, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate(20, 25, 45) retorna a faixa humana" do
    assert_equal "≈ 9–15 min para 20 grupos", divulgacao_duration_estimate(20, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate(1, 25, 45) colapsa lo==hi num valor unico" do
    assert_equal "≈ 1 min para 1 grupos", divulgacao_duration_estimate(1, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate usa Divulgacao::SEND_DELAY_MIN/MAX como default" do
    lo = (3 * Divulgacao::SEND_DELAY_MIN / 60.0).ceil
    hi = (3 * Divulgacao::SEND_DELAY_MAX / 60.0).ceil
    esperado = lo == hi ? "≈ #{lo} min para 3 grupos" : "≈ #{lo}–#{hi} min para 3 grupos"
    assert_equal esperado, divulgacao_duration_estimate(3)
  end

  test "Divulgacao::SEND_DELAY_MIN/MAX caem no fallback 25/45 sem env var" do
    assert_equal 25, Divulgacao::SEND_DELAY_MIN
    assert_equal 45, Divulgacao::SEND_DELAY_MAX
  end

  # --- divulgacao_grupo_error_label (ACOMP-03 / T-30-10) ------------------

  def build_dg(status:, error_code: nil, sent_at: nil)
    client = Client.create!(name: "Helper Test #{SecureRandom.hex(4)}", password: "senha123", password_confirmation: "senha123")
    instance = client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client),
      connection_state: :connected
    )
    group = instance.whatsapp_groups.create!(remote_jid: "hg#{SecureRandom.hex(4)}@g.us", subject: "Grupo Helper", active: true, synced_at: Time.current)
    arte = client.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte")
    arte.media_file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")), filename: "sample.jpg", content_type: "image/jpeg")
    arte.save!
    divulgacao = client.divulgacoes.create!(
      arte: arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: group, group_name: group.display_name, remote_jid: group.remote_jid) ]
    )
    dg = divulgacao.divulgacao_grupos.first
    dg.update!(status: status, error_code: error_code, sent_at: sent_at)
    dg
  end

  test "divulgacao_grupo_error_label mapeia arte_nao_aprovada pro texto pt-BR" do
    dg = build_dg(status: :falhou, error_code: "arte_nao_aprovada")
    assert_equal "Motivo: a aprovação da arte foi retirada antes do envio.", divulgacao_grupo_error_label(dg)
  end

  test "divulgacao_grupo_error_label mapeia instancia_desconectada pro texto pt-BR" do
    dg = build_dg(status: :falhou, error_code: "instancia_desconectada")
    assert_equal "Motivo: o número do cliente estava desconectado no momento do envio.", divulgacao_grupo_error_label(dg)
  end

  test "divulgacao_grupo_error_label com codigo desconhecido cai no fallback Motivo: verbatim" do
    dg = build_dg(status: :incerto, error_code: "Unknown: timeout after 30s")
    assert_equal "Motivo: Unknown: timeout after 30s", divulgacao_grupo_error_label(dg)
  end

  test "divulgacao_grupo_error_label repassa [url-redigida] verbatim, sem re-sanitizar" do
    dg = build_dg(status: :falhou, error_code: "failed to download resource: [url-redigida]")
    assert_equal "Motivo: failed to download resource: [url-redigida]", divulgacao_grupo_error_label(dg)
  end

  # --- divulgacao_placar (ACOMP-03) ---------------------------------------

  def build_divulgacao_com_status(*statuses)
    client = Client.create!(name: "Placar Test #{SecureRandom.hex(4)}", password: "senha123", password_confirmation: "senha123")
    instance = client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client),
      connection_state: :connected
    )
    arte = client.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte")
    arte.media_file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")), filename: "sample.jpg", content_type: "image/jpeg")
    arte.save!

    if statuses.empty?
      divulgacao = client.divulgacoes.new(arte: arte, scheduled_for: 3.days.from_now)
      divulgacao.save!(validate: false) # zero grupos so e alcancavel via backstop, nao pelo form (ao_menos_um_grupo)
      return divulgacao
    end

    groups = statuses.each_with_index.map do |_status, i|
      instance.whatsapp_groups.create!(remote_jid: "pg#{SecureRandom.hex(4)}-#{i}@g.us", subject: "Grupo #{i}", active: true, synced_at: Time.current)
    end
    divulgacao = client.divulgacoes.create!(
      arte: arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: groups.map { |g| DivulgacaoGrupo.new(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid) }
    )
    divulgacao.divulgacao_grupos.zip(statuses).each { |dg, status| dg.update!(status: status) }
    divulgacao
  end

  test "divulgacao_placar com 0 grupos retorna o travessao" do
    divulgacao = build_divulgacao_com_status
    assert_equal "—", divulgacao_placar(divulgacao)
  end

  test "divulgacao_placar com todas pendente retorna N pendentes" do
    divulgacao = build_divulgacao_com_status(:pendente, :pendente, :pendente)
    assert_equal "3 pendentes", divulgacao_placar(divulgacao)
  end

  test "divulgacao_placar com mix incerto>0 e pendente>0 anexa os dois segmentos" do
    divulgacao = build_divulgacao_com_status(:enviado, :falhou, :incerto, :pendente)
    assert_equal "1 enviados · 1 falhou · 1 incerto · 1 pendente", divulgacao_placar(divulgacao)
  end

  test "divulgacao_placar com incerto==0 e pendente==0 mostra so a string base" do
    divulgacao = build_divulgacao_com_status(:enviado, :enviado, :falhou)
    assert_equal "2 enviados · 1 falhou", divulgacao_placar(divulgacao)
  end

  test "divulgacao_placar com um unico grupo pendente nao pluraliza (copy travada)" do
    divulgacao = build_divulgacao_com_status(:pendente)
    assert_equal "1 pendentes", divulgacao_placar(divulgacao)
  end
end
