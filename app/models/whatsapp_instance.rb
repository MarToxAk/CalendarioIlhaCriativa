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
  has_many :whatsapp_groups, dependent: :destroy

  enum :connection_state, { unpaired: 0, awaiting_qr: 1, connected: 2, disconnected: 3 }
  enum :origin,           { created_by_app: 0, adopted_existing: 1 }, prefix: :origin
  # WR-03 (code review fase 27): valor renomeado de `error` para `sync_error`
  # -- com prefix: :groups_sync, `error:` geraria `groups_sync_error?`, que
  # colide com o método de presença auto-gerado pelo Rails para a coluna
  # string `groups_sync_error` (mesmo nome, semântica oposta: "estado ==
  # error?" vs "atributo presente?"). `sync_error:` elimina a colisão.
  enum :groups_sync_state, { idle: 0, syncing: 1, sync_error: 2 }, prefix: :groups_sync

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

  # Fonte única do mapa estado Evolution -> connection_state.
  EVOLUTION_STATE_MAP = {
    "open" => :connected, "connecting" => :awaiting_qr, "close" => :disconnected, "refused" => :disconnected
  }.freeze

  # Qualquer valor desconhecido (nil, string vazia, evento futuro) cai em
  # :awaiting_qr por default — nunca levanta KeyError.
  def self.map_evolution_state(state)
    EVOLUTION_STATE_MAP.fetch(state, :awaiting_qr)
  end

  # WR-06 — o receiver de webhook usa isto para IGNORAR um state que o
  # Evolution não emite hoje (payload malformado, ou string nova de uma
  # release futura chegando de um caller assinado) em vez de rebaixar uma
  # instância `connected` para `awaiting_qr`. map_evolution_state mantém o
  # default :awaiting_qr — a garantia "nunca levanta KeyError" continua.
  def self.known_evolution_state?(state)
    EVOLUTION_STATE_MAP.key?(state.to_s)
  end

  def paired_days = paired_at && ((Time.current - paired_at) / 1.day).floor
  def recently_paired? = paired_days && paired_days < 7

  # Rótulo pt-BR por estado (26-UI-SPEC "Connection-state -> color map"). Usado
  # pelo controller (flash de #verify) e pela view (26-05). O sufixo "(adotada)"
  # para connected + origin_adopted_existing? é responsabilidade da VIEW, não
  # deste método — mantém o método puro/sem contexto de origem.
  def connection_state_label
    case connection_state
    when "unpaired" then "Aguardando criação"
    when "awaiting_qr" then "Aguardando pareamento"
    when "connected" then "Conectada"
    when "disconnected" then "Desconectada"
    end
  end
end
