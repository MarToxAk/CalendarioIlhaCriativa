# frozen_string_literal: true

module Whatsapp
  # Sincroniza os grupos de UMA whatsapp_instance a partir de um Evolution::Client
  # injetado (fase 27, GRUPO-01). Orquestração + persistência ficam aqui;
  # Evolution::Client permanece transporte HTTP puro. Analog:
  # app/services/evolution/instance_provisioner.rb (DI seam client_api:).
  #
  # Caminho feliz (Task 1): grava os grupos retornados via upsert_all, keyed em
  # [whatsapp_instance_id, remote_jid]. O guard de instância não conectada e a
  # passada de desativação (GRUPO-05) chegam na Task 2.
  class GroupSynchronizer
    Result = Struct.new(:ok, :count, :reason, keyword_init: true)

    def initialize(instance, client_api: Evolution::Client)
      @instance = instance
      @api = client_api
    end

    def call
      batch_started_at = Time.current
      raw  = @api.fetch_groups(@instance.instance_name, api_key: @instance.token)
      rows = Array(raw).filter_map { |g| row_for(g, batch_started_at) }

      WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?

      @instance.update!(groups_synced_at: batch_started_at,
                         groups_sync_state: :idle,
                         groups_sync_error: nil)

      Result.new(ok: true, count: rows.size)
    end

    private

    # Grava só as chaves exatas do payload que interessam ao cache local — NUNCA
    # created_at/updated_at (Rails 8.1 auto-injeta para upsert_all; incluir
    # explicitamente quebra com "multiple assignments to same column").
    def row_for(g, ts)
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
