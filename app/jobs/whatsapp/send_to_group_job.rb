# frozen_string_literal: true

# Whatsapp::SendToGroupJob — corpo completo do `perform` (fase 29-01) +
# taxonomia de erro completa e concorrência por instância (fase 29-02). Claim
# atômico ANTES de qualquer I/O de rede — a única defesa real contra
# double-send (ENVIO-04; provado sob condição adversarial em
# test/jobs/whatsapp/send_to_group_job_test.rb). Revalida
# `arte.approved?`/`instance.connected?` DENTRO do `perform`, nunca confiando
# num check feito uma única vez no DispatchJob (ENVIO-06/07). Token sempre via
# `divulgacao.client.whatsapp_instance.token` (SEG-03) — a MESMA cadeia de
# resolução usada pela chave de `limits_concurrency` abaixo, fixada no
# checkpoint da Task 1 do 29-01-PLAN.md para nunca divergir.
# `finalize_divulgacao_if_done` é MÉTODO DE CLASSE porque os blocos
# `discard_on`/`retry_on` abaixo (que rodam fora do `perform`, no mesmo `self`
# de classe — igual ao `self.mark_error` de Whatsapp::SyncGroupsJob) precisam
# chamá-lo.
class Whatsapp::SendToGroupJob < ApplicationJob
  queue_as :whatsapp_sends # config/queue.yml: worker "*" genérico pega até a fila dedicada chegar no 29-03 (INFRA-06)

  # URL de mídia presignada gerada DENTRO do perform (ENVIO-08) — validade
  # curta o suficiente para cobrir só este envio individual, evitando que a
  # URL do último grupo de uma Divulgação grande expire antes do download.
  MEDIA_URL_TTL = 5.minutes

  # Pitfall 6 do RESEARCH: `error_code` é `t.string` sem `limit:` — Postgres
  # aceitaria qualquer tamanho. Truncamento explícito é código, não confiança
  # na coluna, para nunca gravar um blob grande (potencial trace/fragmento
  # sensível) no banco.
  ERROR_CODE_MAX_LENGTH = 500

  # ENVIO-09 — nunca dois envios da MESMA instância em paralelo. `key:` usa a
  # cadeia IDÊNTICA à do token (SEG-03) acima — se um dia divergirem, a
  # concorrência serializaria a instância errada (ou nenhuma), e o teste de
  # regressão "concurrency_key resolve para o whatsapp_instance_id do grupo"
  # existe justamente para pegar isso. `on_conflict:` fica no default do gem
  # (`:block`) -- NUNCA `:discard`, que perderia o envio silenciosamente; um
  # job sem slot só fica em `solid_queue_blocked_executions` até liberar.
  # WR-01: `whatsapp_instance` é `has_one` e PODE ser nil -- a mesma razão pela
  # qual o guard `instance&.connected?` no `perform` usa safe navigation. Este
  # lambda roda SÍNCRONO no enqueue (`perform_later`), dentro do loop do
  # DispatchJob; um `NoMethodError` aqui abortaria o dispatch de todos os
  # grupos irmãos. Com `&.id` a chave vira nil -> ActiveJob trata como "não
  # limitado" (roda sem serialização), o que é seguro: a primeira linha do
  # `perform` (`instance&.connected?`) já derruba o job para :falhou sem tocar
  # na Evolution.
  limits_concurrency to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance&.id }

  # 27-REVIEW.md WR-A / RESEARCH Pitfall 3 (verificado contra
  # activesupport-8.1.3/lib/active_support/rescuable.rb:129):
  # `rescue_handlers.reverse_each.detect` usa o handler declarado por ÚLTIMO
  # como prioridade mais ALTA. Este catch-all PRECISA ser o primeiro
  # `discard_on`/`retry_on` declarado na classe -- senão ele venceria sempre
  # (StandardError é superclasse de toda a taxonomia Evolution::Errors) e
  # engoliria os handlers específicos declarados depois, matando o retry de
  # Transient silenciosamente.
  discard_on(StandardError) do |job, err|
    Rails.logger.error(
      "[Whatsapp::SendToGroupJob] erro inesperado (fora da taxonomia Evolution::Errors): " \
      "#{err.class}: #{err.message}\n#{err.backtrace&.first(10)&.join("\n")}"
    )
    mark_falhou(job, "unexpected_error")
  end

  # Transient só é levantado quando NADA foi enviado ainda (falha de conexão,
  # antes de qualquer byte trafegar -- Evolution::Client#request's
  # `rescue Faraday::ConnectionFailed`/`classify_timeout`'s ramo
  # `Net::OpenTimeout`). O `retry_on` aqui reenfileira; o `rescue` pontual
  # dentro de `perform` (abaixo) é o que garante que a PRÓXIMA tentativa
  # encontre o item `pendente` de novo -- sem ele, o claim já teria virado
  # `enviado` e toda retentativa automática seria um no-op silencioso,
  # deixando `retry_on` funcionalmente morto (T-29-05 do threat model).
  retry_on(Evolution::Errors::Transient, wait: :polynomially_longer, attempts: 5) do |job, _err|
    mark_falhou(job, "transient")
  end

  # Read-timeout/reset no meio da resposta -- PODE já ter sido processado do
  # lado do WhatsApp. NUNCA retry automático (ENVIO-05) -- vira `incerto`,
  # nunca `falhou`, sinalizando que o item precisa de checagem manual, não
  # reenvio automático que arriscaria duplicar a mensagem.
  discard_on(Evolution::Errors::Unknown) { |job, err| mark_incerto(job, err) }

  # 4xx (payload/rota/credencial) já normalizado por raise_for_status! -- o
  # texto livre nunca ecoa header/apikey/URL.
  discard_on(Evolution::Errors::Permanent) { |job, err| mark_falhou(job, err.message) }

  # Instância caiu EXATAMENTE durante a chamada Evolution, depois do guard
  # `instance.connected?` já ter passado dentro de `perform` -- defesa em
  # profundidade, mesmo error_code estático do guard inline.
  discard_on(Evolution::Errors::NotConnected) { |job, _err| mark_falhou(job, "instancia_desconectada") }

  # Mensagem estática do módulo Evolution (base_url/apikey ausente) -- nunca
  # inclui segredo.
  discard_on(Evolution::Errors::ConfigurationError) { |job, err| mark_falhou(job, err.message) }

  discard_on(ActiveJob::DeserializationError) # grupo/divulgação apagados mid-flight -- sem efeito colateral

  def perform(group)
    group.reload
    divulgacao = group.divulgacao.reload
    return if divulgacao.status_cancelada? # DIVU-08/DIVU-09: no-op silencioso, item permanece pendente

    claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                              .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
    return if claimed.zero? # ENVIO-04: já processado por outro worker/retry — nunca chega ao HTTP

    arte = divulgacao.arte.reload
    unless arte.approved?
      # CR-01: o claim atômico acima setou `sent_at` como parte do flip para
      # :enviado; aqui a Evolution NUNCA foi chamada, então `sent_at` tem que
      # voltar a nil -- uma linha `falhou` nunca pode carregar timestamp de envio.
      group.update!(status: :falhou, sent_at: nil, error_code: "arte_nao_aprovada") # ENVIO-06
      self.class.finalize_divulgacao_if_done(divulgacao)
      return
    end

    instance = divulgacao.client.whatsapp_instance
    unless instance&.connected?
      # CR-01: idem -- Evolution nunca chamada neste guard, limpa o `sent_at` do claim.
      group.update!(status: :falhou, sent_at: nil, error_code: "instancia_desconectada") # ENVIO-07
      self.class.finalize_divulgacao_if_done(divulgacao)
      return
    end

    begin
      send_via_evolution(group, arte, instance)
    rescue Evolution::Errors::Transient
      # Desfaz o claim ANTES de re-levantar -- sem isso a próxima tentativa
      # automática do retry_on encontraria status: enviado (do claim acima) e
      # o claim atômico devolveria 0 linhas, virando no-op para sempre. Seguro
      # por construção: Transient só é levantado quando nada foi enviado
      # ainda (ver comentário do retry_on acima). `reload` é OBRIGATÓRIO aqui
      # -- `group` nunca foi recarregado depois do `update_all` (bulk SQL) do
      # claim acima, então o dirty-tracking em memória ainda acha `status`
      # "pendente" (valor anterior ao claim) e um `update!(status: :pendente)`
      # sem reload seria tratado como NENHUMA mudança, silenciosamente
      # deixando a coluna presa em "enviado" no banco.
      group.reload.update!(status: :pendente, sent_at: nil, updated_at: Time.current)
      raise
    end
    self.class.finalize_divulgacao_if_done(divulgacao)
  end

  def self.finalize_divulgacao_if_done(divulgacao)
    return if divulgacao.divulgacao_grupos.pendente.exists?
    divulgacao.update!(status: :concluida) if divulgacao.status_em_andamento?
  end

  def self.mark_falhou(job, message)
    group = job.arguments.first
    # CR-01: espelha o revert de `sent_at` do rescue Transient no `perform`. O
    # claim atômico seta `sent_at` ao flipar para :enviado; toda saída que NÃO
    # termina em :enviado tem que zerar de novo, senão uma linha :falhou fica
    # com timestamp de "envio" que nunca aconteceu (audit trail enganoso para
    # as telas de histórico da fase 30, que leem `divulgacao_grupos.sent_at`).
    group.update!(status: :falhou, sent_at: nil, error_code: message.to_s.first(ERROR_CODE_MAX_LENGTH))
    finalize_divulgacao_if_done(group.divulgacao.reload)
  end

  def self.mark_incerto(job, err)
    group = job.arguments.first
    # CR-01: `incerto` = read-timeout, a mensagem PODE ter sido entregue de
    # fato -- por isso `sent_at` é DELIBERADAMENTE preservado aqui (ao
    # contrário de :falhou), sinalizando "tentamos, resultado incerto".
    group.update!(status: :incerto, error_code: err.message.to_s.first(ERROR_CODE_MAX_LENGTH))
    finalize_divulgacao_if_done(group.divulgacao.reload)
  end

  private

  def send_via_evolution(group, arte, instance)
    api_key = instance.token # SEG-03 — sempre resolvido via divulgacao.client.whatsapp_instance, nunca um id solto

    resp = if arte.caption_only?
      Evolution::Client.send_text(instance.instance_name, number: group.remote_jid, text: arte.caption, api_key: api_key)
    else
      media_url = arte.media_file.url(expires_in: MEDIA_URL_TTL) # ENVIO-08 — gerada aqui, nunca no DispatchJob
      Evolution::Client.send_media(instance.instance_name, number: group.remote_jid, mediatype: arte.media_type,
                                    media: media_url, api_key: api_key, caption: arte.caption.presence)
    end

    # RESEARCH Assumption A1: shape exato do sucesso PENDENTE de UAT real — ler os dois formatos possíveis.
    group.update!(evolution_message_id: resp["key"]&.dig("id") || resp["id"])
  end
end
