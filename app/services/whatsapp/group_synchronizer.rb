# frozen_string_literal: true

module Whatsapp
  # Sincroniza os grupos de UMA whatsapp_instance a partir de um Evolution::Client
  # injetado (fase 27, GRUPO-01). Orquestração + persistência ficam aqui;
  # Evolution::Client permanece transporte HTTP puro. Analog:
  # app/services/evolution/instance_provisioner.rb (DI seam client_api:).
  #
  # Grava os grupos retornados via upsert_all, keyed em
  # [whatsapp_instance_id, remote_jid]. Guarda contra instância não conectada
  # ANTES de qualquer HTTP, e roda a passada de desativação (GRUPO-05) depois do
  # upsert — grupos sumidos do lote viram active:false, nunca delete/destroy.
  class GroupSynchronizer
    Result = Struct.new(:ok, :count, :reason, keyword_init: true)

    def initialize(instance, client_api: Evolution::Client)
      @instance = instance
      @api = client_api
    end

    def call
      # Defense-in-depth (RESEARCH Pitfall 7): connection_state é coluna
      # cacheada; o controller no 27-02 também guarda antes de enfileirar.
      unless @instance.connected?
        @instance.update!(groups_sync_state: :sync_error, groups_sync_error: "not_connected")
        return Result.new(ok: false, reason: :not_connected)
      end

      batch_started_at = Time.current
      raw  = @api.fetch_groups(@instance.instance_name, api_key: @instance.token)
      rows = Array(raw).filter_map { |g| row_for(g, batch_started_at) }

      WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?

      # GRUPO-05: escopado pela associação (nunca toca outra instância), "<"
      # estrito, updated_at explícito (update_all não auto-toca). Roda MESMO
      # com rows vazio — o `if rows.any?` acima só guarda o upsert_all
      # (upsert_all([]) levanta ArgumentError — Pitfall 4). NUNCA delete/destroy.
      @instance.whatsapp_groups
               .where(active: true)
               .where("synced_at < ?", batch_started_at)
               .update_all(active: false, updated_at: Time.current)

      @instance.update!(groups_synced_at: batch_started_at,
                         groups_sync_state: :idle,
                         groups_sync_error: nil)

      Result.new(ok: true, count: rows.size)
    end

    private

    # Grava só as chaves exatas do payload que interessam ao cache local — NUNCA
    # created_at/updated_at (Rails 8.1 auto-injeta para upsert_all; incluir
    # explicitamente quebra com "multiple assignments to same column").
    #
    # 27-REVIEW.md WR-2: Evolution::Client#fetch_groups só valida que o topo é
    # um Array — não valida a forma de cada elemento. Um elemento não-Hash
    # (nil ou outro tipo) faria g["id"] levantar NoMethodError, que hoje só
    # seria capturado pelo discard_on(StandardError) catch-all do job
    # (27-REVIEW.md WR-1), mascarando uma regressão real de contrato da API
    # como flakiness de rede transitória. filter_map descarta o elemento e
    # segue o batch em vez de crashar.
    def row_for(g, ts)
      return nil unless g.is_a?(Hash)

      jid = g["id"].to_s
      return nil unless jid.end_with?("@g.us")

      {
        whatsapp_instance_id: @instance.id,
        remote_jid: jid,
        subject:    g["subject"].presence,
        announce:   g["announce"] == true,
        active:     true,
        synced_at:  ts
      }
    end
  end
end
