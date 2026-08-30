# frozen_string_literal: true

# Fail-fast no boot em produção para o transporte Evolution (EVO-02).
# Os readers e constantes vivem em app/services/evolution.rb (namespace explícito
# gerenciado pelo Zeitwerk). Sem base_url/apikey o milestone v1.7 inteiro não
# funciona, e um host http:// atrás da Cloudflare é sempre erro de config
# (TLS terminado na CF — ver .planning/notes/evolution-contract.md e
# 25-RESEARCH.md Pattern 2).
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  # SECRET_KEY_BASE_DUMMY só é setada pelo Rails no `assets:precompile` (build da imagem,
  # sem config/master.key) — Evolution.global_api_key levantaria ConfigurationError ali.
  # O runtime real nunca seta essa var, então o fail-fast de boot continua ativo (CR-01 / 25-05).
  next if ENV["SECRET_KEY_BASE_DUMMY"]

  Evolution.global_api_key
  unless Evolution.base_url.start_with?("https://")
    raise Evolution::Errors::ConfigurationError,
          "EVOLUTION_BASE_URL deve começar com https:// (Cloudflare termina o TLS na frente do host) — ver evolution-contract.md"
  end
end
