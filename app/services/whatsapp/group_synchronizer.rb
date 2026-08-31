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
      # Fase 31 (D-05, Pitfall 5): o guard de não-conectado e a escrita de
      # :sync_error ficam SÓ em @instance — NUNCA propagados às irmãs (elas
      # nunca entraram em :syncing, então nunca ficam presas nesse estado).
      unless @instance.connected?
        @instance.update!(groups_sync_state: :sync_error, groups_sync_error: "not_connected")
        return Result.new(ok: false, reason: :not_connected)
      end

      batch_started_at = Time.current
      # Fase 31 (D-05, Pitfall 6): UMA chamada fetch_groups, FORA de qualquer
      # loop de irmãs. token/instance_name são idênticos entre irmãs (copiados
      # em InstanceProvisioner#reuse) — qualquer uma serve de fonte. Repetir a
      # chamada por irmã multiplicaria os ~40s de fetchAllGroups por cliente.
      raw = @api.fetch_groups(@instance.instance_name, api_key: @instance.token)

      # Fase 31 (D-05): irmãs = todas as WhatsappInstance com o mesmo
      # instance_name (inclui @instance). Sem irmãs, devolve [self] — o loop
      # abaixo roda exatamente 1 vez, byte-idêntico ao comportamento anterior
      # a esta fase (regressão single-instance).
      rows = nil
      WhatsappInstance.where(instance_name: @instance.instance_name).find_each do |sib|
        rows = Array(raw).filter_map { |g| row_for(g, batch_started_at, sib) }

        WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?

        # GRUPO-05: escopado pela associação de CADA irmã (nunca toca outra
        # instância), "<" estrito, updated_at explícito (update_all não
        # auto-toca), mesmo batch_started_at de referência para todas. Roda
        # MESMO com rows vazio — o `if rows.any?` acima só guarda o upsert_all
        # (upsert_all([]) levanta ArgumentError — Pitfall 4). NUNCA delete/destroy.
        sib.whatsapp_groups
           .where(active: true)
           .where("synced_at < ?", batch_started_at)
           .update_all(active: false, updated_at: Time.current)

        sib.update!(groups_synced_at: batch_started_at,
                     groups_sync_state: :idle,
                     groups_sync_error: nil)
      end

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
    #
    # Fase 31 (D-05): recebe a irmã (`sib`) em vez de fechar sobre @instance —
    # cada irmã grava suas próprias linhas em whatsapp_groups, escopadas ao
    # próprio whatsapp_instance_id.
    def row_for(g, ts, sib)
      return nil unless g.is_a?(Hash)

      jid = g["id"].to_s
      return nil unless jid.end_with?("@g.us")

      {
        whatsapp_instance_id: sib.id,
        remote_jid: jid,
        subject:    g["subject"].presence,
        announce:   g["announce"] == true,
        active:     true,
        synced_at:  ts
      }
    end
  end
end
