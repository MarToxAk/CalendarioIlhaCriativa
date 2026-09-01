# frozen_string_literal: true

# Configuração do transporte Evolution (EVO-02) — namespace explícito para o
# Zeitwerk gerenciar Evolution::Client e Evolution::Errors como filhos.
#
# Precedência de segredo espelha app/services/api/jwt_service.rb#secret, porém
# ENV-first (dev usa .env via dotenv-rails dev/test; produção usa credentials).
# Valores e timeouts derivados de 25-RESEARCH.md Pattern 2 e
# .planning/notes/evolution-contract.md (verificado contra o host real 2026-08-29):
#   - Cloudflare na frente do host impõe teto de ~100s; nunca passar de 60s.
#   - open 5s / write 10s / read 30s no geral; read 15s nas leituras rápidas.
#
# O fail-fast de boot em produção vive em config/initializers/evolution.rb.
module Evolution
  # Config do transporte Evolution vem SÓ de variável de ambiente (.env / docker-compose).
  # O fallback para config/credentials.yml.enc foi removido (deploy env-driven) — a var
  # ausente é erro de configuração, nunca silenciosa.

  # Resolve base_url de ENV["EVOLUTION_BASE_URL"].
  def self.base_url
    value = ENV["EVOLUTION_BASE_URL"]
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_BASE_URL não configurado (variável de ambiente) — ver .env.example / 25-RESEARCH.md Pattern 2"
    end
    value
  end

  # Resolve a apikey global de ENV["EVOLUTION_GLOBAL_API_KEY"].
  def self.global_api_key
    value = ENV["EVOLUTION_GLOBAL_API_KEY"]
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_GLOBAL_API_KEY não configurado (variável de ambiente) — ver .env.example / 25-RESEARCH.md Pattern 2"
    end
    value
  end

  # Resolve a chave HMAC do webhook de ENV["EVOLUTION_WEBHOOK_HMAC_KEY"]
  # (fase 26, PAIR-06 — assinatura do webhook).
  def self.webhook_hmac_key
    value = ENV["EVOLUTION_WEBHOOK_HMAC_KEY"]
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_WEBHOOK_HMAC_KEY não configurado (variável de ambiente) — ver .env.example / 26-RESEARCH.md"
    end
    value
  end

  # Resolve a base URL pública do webhook de ENV["EVOLUTION_WEBHOOK_BASE_URL"]
  # (fase 26 — host público que recebe /webhooks/evolution).
  def self.webhook_base_url
    value = ENV["EVOLUTION_WEBHOOK_BASE_URL"]
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_WEBHOOK_BASE_URL não configurado (variável de ambiente) — ver .env.example / 26-RESEARCH.md"
    end
    value
  end

  OPEN_TIMEOUT       = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT", "5"))
  WRITE_TIMEOUT      = Integer(ENV.fetch("EVOLUTION_WRITE_TIMEOUT", "10"))
  READ_TIMEOUT       = Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT", "30"))
  READ_TIMEOUT_FAST  = 15 # connectionState / fetchInstances

  # fetchAllGroups NÃO é uma leitura rápida como as demais: o próprio Evolution
  # API 2.3.7 faz uma chamada profilePicture(group.id) por grupo, DENTRO do
  # loop do servidor (.planning/research/FEATURES.md:243), então o tempo de
  # resposta escala com o número de grupos da instância. Medido empiricamente
  # nesta sessão de correção contra a instância real de produção
  # `livia_client_31` (64 grupos): com READ_TIMEOUT_FAST (15s) a chamada
  # estourava em Net::ReadTimeout; repetindo com 90s o host respondeu em
  # ~40s. 60s dá margem folgada sem se aproximar do teto de ~100s do
  # Cloudflare já documentado no cabeçalho deste arquivo.
  READ_TIMEOUT_GROUPS = Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT_GROUPS", "60"))
end
