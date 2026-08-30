# frozen_string_literal: true

# Instância Evolution 1:1 por cliente (EVO-04, fase 26). encrypts :token cifra o
# segredo em repouso (AES-GCM, não-determinístico); as 3 chaves de
# active_record_encryption vivem em credentials.evolution/ENV desde o passo 1
# desta fase (ordem obrigatória do ROADMAP — nunca gravar antes das chaves
# existirem). map_evolution_state é a ÚNICA definição do mapa estado Evolution
# -> connection_state da fase inteira (26-02 adopt, 26-03 webhook receiver,
# 26-04 #verify TODOS chamam este método — nenhum reimplementa o Hash).
class WhatsappInstance < ApplicationRecord
  belongs_to :client
  encrypts :token

  enum :connection_state, { unpaired: 0, awaiting_qr: 1, connected: 2, disconnected: 3 }
  enum :origin,           { created_by_app: 0, adopted_existing: 1 }, prefix: :origin

  # Nome determinístico e estável da instância no Evolution — namespaced porque
  # o manager é compartilhado com outras apps da agência. client.id não rotaciona
  # (ao contrário de access_token), então a adoção de instância existente pode
  # confiar neste nome sem I/O extra.
  def self.evolution_name_for(client) = "livia_client_#{client.id}"

  # HMAC-SHA256(instance_name, chave global) — determinístico e não persistido
  # (PAIR-06). O receiver de webhook recalcula com o mesmo método e compara via
  # secure_compare ANTES de tocar o banco.
  def self.webhook_secret_for(instance_name)
    OpenSSL::HMAC.hexdigest("SHA256", Evolution.webhook_hmac_key, instance_name)
  end

  # Fonte única do mapa estado Evolution -> connection_state. Qualquer valor
  # desconhecido (nil, string vazia, evento futuro) cai em :awaiting_qr por
  # default — nunca levanta KeyError.
  def self.map_evolution_state(state)
    { "open" => :connected, "connecting" => :awaiting_qr, "close" => :disconnected, "refused" => :disconnected }
      .fetch(state, :awaiting_qr)
  end

  def paired_days = paired_at && ((Time.current - paired_at) / 1.day).floor
  def recently_paired? = paired_days && paired_days < 7
end
