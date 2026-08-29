# frozen_string_literal: true

module Evolution
  # Taxonomia de erro do transporte Evolution (EVO-03).
  # Espelha o módulo aninhado Api::Errors de app/services/api/jwt_service.rb.
  # Nenhuma Faraday::Error / status HTTP cru escapa de Evolution::Client — tudo
  # é traduzido para uma destas classes. O chamador decide retry/discard pela
  # classe, nunca pelo status. Ver 25-RESEARCH.md Pattern 3 + evolution-contract.md.
  module Errors
    # base_url / apikey ausente — falha no boot em produção
    class ConfigurationError < StandardError; end
    # timeout de conexão, 5xx, ECONNREFUSED, corpo 5xx não-JSON da Cloudflare → retry seguro (fase 29)
    class Transient < StandardError; end
    # 401/403 (credencial), 400/404/422 (payload/rota) → retry não conserta
    class Permanent < StandardError; end
    # read-timeout / reset no meio da resposta → PODE ter sido processado; NUNCA retry automático
    class Unknown < StandardError; end
    # connectionState != "open" → precisa de novo QR (fase 26)
    class NotConnected < StandardError; end
  end
end
