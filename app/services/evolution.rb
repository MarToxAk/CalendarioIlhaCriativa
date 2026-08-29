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
  # Resolve base_url de ENV["EVOLUTION_BASE_URL"] ou credentials.evolution.base_url.
  def self.base_url
    value = ENV.fetch("EVOLUTION_BASE_URL") { Rails.application.credentials.dig(:evolution, :base_url) }
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_BASE_URL não configurado (ENV ou credentials.evolution.base_url) — ver 25-RESEARCH.md Pattern 2"
    end
    value
  end

  # Resolve a apikey global de ENV["EVOLUTION_GLOBAL_API_KEY"] ou credentials.evolution.global_api_key.
  def self.global_api_key
    value = ENV.fetch("EVOLUTION_GLOBAL_API_KEY") { Rails.application.credentials.dig(:evolution, :global_api_key) }
    if value.blank?
      raise Evolution::Errors::ConfigurationError,
            "EVOLUTION_GLOBAL_API_KEY não configurado (ENV ou credentials.evolution.global_api_key) — ver 25-RESEARCH.md Pattern 2"
    end
    value
  end

  OPEN_TIMEOUT       = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT", "5"))
  WRITE_TIMEOUT      = Integer(ENV.fetch("EVOLUTION_WRITE_TIMEOUT", "10"))
  READ_TIMEOUT       = Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT", "30"))
  READ_TIMEOUT_FAST  = 15 # connectionState / fetchInstances / fetchAllGroups
end
