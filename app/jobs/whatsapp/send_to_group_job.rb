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
  # grupos irmãos -- por isso o `&.id`.
  #
  # Cuidado com o ramo sem instância: uma `key:` que retorna nil NÃO desliga o
  # limite. Em solid_queue 1.4.0 (active_job/concurrency_controls.rb) a chave
  # vira `[concurrency_group, nil].compact.join("/")` => a string crua da
  # classe `"Whatsapp::SendToGroupJob"`, e `concurrency_limited?` continua
  # `true` -- ou seja, TODO job sem instância, de QUALQUER cliente, disputaria
  # um único slot global `to: 1`. Para evitar essa serialização global
  # acidental o ramo sem instância devolve um sentinel único por grupo
  # (`send_to_group:no_instance:<id>`), dando a cada job seu próprio slot.
  # É latente/inalcançável hoje (nenhum caminho destrói uma WhatsappInstance
  # sem destruir o Client e suas divulgações junto), mas mantém o fallback são
  # se algum dia virar alcançável -- e de qualquer forma a primeira linha do
  # `perform` (`instance&.connected?`) já derruba o job para :falhou sem tocar
  # na Evolution.
  limits_concurrency to: 1,
    key: ->(group) {
      group.divulgacao.client.whatsapp_instance&.id ||
        "send_to_group:no_instance:#{group.id}"
    }

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

  # WR-02: `DeserializationError` aqui só ocorre se o `DivulgacaoGrupo` (o
  # único argumento do job) sumiu entre enqueue e execução. Isso NÃO deixa
  # uma divulgação órfã presa em :em_andamento: `divulgacao_grupos` só é
  # apagado em cascata por `Divulgacao#destroy` (que por sua vez só dispara
  # via `Client#destroy`), e nesse caso a própria Divulgacao é destruída
  # junto -- não sobra nada para `finalize_divulgacao_if_done`. Um bloco que
  # tentasse resolver a divulgação aqui seria código morto de qualquer forma:
  # `job.arguments` re-dispara a mesma `DeserializationError` (activejob 8.1
  # não limpa `@serialized_arguments` quando a desserialização falha).
  # Descarte simples e honesto.
  discard_on(ActiveJob::DeserializationError)

  def perform(group)
    group.reload
    divulgacao = group.divulgacao.reload
    return if divulgacao.status_cancelada? # DIVU-08/DIVU-09: no-op silencioso, item permanece pendente

    # CR-01: o claim NÃO seta `sent_at` -- ele só precisa flipar o status para
    # :enviado para fazer seu trabalho de lock atômico. `sent_at` é setado
    # EXCLUSIVAMENTE em `send_via_evolution`, depois da Evolution confirmar o
    # aceite. Invariante resultante: `sent_at != nil` <=> "envio confirmado".
    # Antes, o claim setava `sent_at` e só o rescue Transient revertia --
    # todo outro caminho de falha (arte_nao_aprovada, instancia_desconectada,
    # mark_falhou/mark_incerto) deixava um timestamp real numa linha que nunca
    # foi enviada, poluindo o audit trail que a fase 30 renderiza.
    claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                              .update_all(status: :enviado, updated_at: Time.current)
    return if claimed.zero? # ENVIO-04: já processado por outro worker/retry — nunca chega ao HTTP

    arte = divulgacao.arte.reload
    unless arte.approved?
      group.update!(status: :falhou, error_code: "arte_nao_aprovada") # ENVIO-06
      self.class.finalize_divulgacao_if_done(divulgacao)
      return
    end

    instance = divulgacao.client.whatsapp_instance
    unless instance&.connected?
      group.update!(status: :falhou, error_code: "instancia_desconectada") # ENVIO-07
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
      # deixando a coluna presa em "enviado" no banco. `sent_at` já é nil
      # (o claim não o seta mais -- CR-01), mas mantemos `sent_at: nil` aqui
      # como defesa em profundidade caso o fluxo mude.
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
    # CR-01: `sent_at` nunca foi setado pelo claim (só `send_via_evolution` o
    # seta, na confirmação de sucesso), então uma linha que chega aqui já tem
    # `sent_at` nil. Mantemos `sent_at: nil` explícito como defesa em
    # profundidade -- uma linha :falhou NUNCA pode carregar timestamp de envio.
    group.reload.update!(status: :falhou, sent_at: nil, error_code: sanitize_error_code(message))
    finalize_divulgacao_if_done(group.divulgacao.reload)
  end

  def self.mark_incerto(job, err)
    group = job.arguments.first
    # CR-01: `incerto` só é alcançado via `discard_on(Unknown)`, e Unknown é
    # levantado de DENTRO de `send_via_evolution` ANTES da linha que seta
    # `sent_at` -- então `sent_at` é nil aqui, coerente com "só confirmação
    # positiva popula sent_at". O status :incerto (não o sent_at) é o sinal de
    # "tentamos, resultado incerto, precisa checagem manual".
    group.reload.update!(status: :incerto, sent_at: nil, error_code: sanitize_error_code(err.message))
    finalize_divulgacao_if_done(group.divulgacao.reload)
  end

  # WR-03: o texto do erro 4xx do Evolution é FREE TEXT
  # (`BadRequestException(error.toString())`, evolution-contract.md, PENDENTE
  # de UAT) e pode ecoar de volta a URL presignada de mídia que recebeu
  # ("failed to download resource: <url>"). `error_code` é armazenamento
  # durável que a fase 30 renderiza a admins -- uma URL GET presignada (ainda
  # que expire em MEDIA_URL_TTL) visível num campo de erro é uma superfície
  # real de information-disclosure. Redige qualquer substring com cara de URL
  # http(s) ANTES de truncar/persistir.
  URL_IN_TEXT = %r{https?://[^\s"'<>)\]]+}i
  # WR-03 (re-review): o esquema `https://` nem sempre acompanha a URL no
  # texto ecoado -- algumas libs de download logam host+path sem ele, ou
  # ecoam só o fragmento de query presignada. Duas passadas extras, ambas
  # conservadoras (redigem só o trecho sensível, nunca a string inteira):
  #  (a) host terminando num domínio conhecido de bucket/CDN seguido de
  #      path + querystring -- `bucket.s3.amazonaws.com/k/1.jpg?X-Amz-...`;
  #  (b) qualquer parâmetro de assinatura solto -- `X-Amz-Signature=...`,
  #      `X-Amz-Credential=...`, `X-Goog-Signature=...`, `Signature=...`.
  SCHEMELESS_SIGNED_URL = %r{
    [\w.-]+\.(?:amazonaws\.com|cloudfront\.net|googleapis\.com|
    r2\.cloudflarestorage\.com|digitaloceanspaces\.com|backblazeb2\.com)
    /[^\s"'<>)\]]*\?[^\s"'<>)\]]+
  }ix
  SIGNED_QUERY_PARAM = /\b(?:X-Amz-[A-Za-z-]+|X-Goog-[A-Za-z-]+|Signature|AWSAccessKeyId)=[^&\s"'<>)\]]+/i
  def self.sanitize_error_code(message)
    message.to_s
           .gsub(URL_IN_TEXT, "[url-redigida]")
           .gsub(SCHEMELESS_SIGNED_URL, "[url-redigida]")
           .gsub(SIGNED_QUERY_PARAM, "[url-redigida]")
           .first(ERROR_CODE_MAX_LENGTH)
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
    # WR-05: `&.` só protege contra `resp["key"]` nil, não contra ele ser
    # present-but-not-a-Hash (string/bool num shape futuro/observado). Sem o
    # `is_a?(Hash)` um `.dig` cru levantaria NoMethodError DEPOIS do envio já
    # confirmado -> o catch-all `discard_on(StandardError)` marcaria :falhou
    # uma mensagem que de fato foi entregue.
    key = resp["key"]
    message_id = (key.is_a?(Hash) ? key["id"] : nil) || resp["id"]
    # CR-01: ÚNICO ponto que popula `sent_at` -- só aqui há confirmação
    # positiva de que a Evolution aceitou o envio. Invariante: `sent_at != nil`
    # <=> "envio confirmado" (nunca setado pelo claim, nunca sobra numa linha
    # :falhou/:incerto).
    group.reload.update!(status: :enviado, evolution_message_id: message_id, sent_at: Time.current)
  end
end
