# frozen_string_literal: true

# Fail-fast no boot em produção para a config env-driven (EVO-02 + INFRA-01 + AR encryption).
# Os readers e constantes do Evolution vivem em app/services/evolution.rb; a config de S3
# vive em config/storage.yml; as chaves de encriptação em config/initializers/active_record_encryption.rb.
# Toda essa config vem SÓ de variável de ambiente (.env / docker-compose) — sem fallback
# para config/credentials.yml.enc. A var ausente em produção é boot-fatal (nunca silenciosa);
# em dev/test a ausência degrada (Evolution só falha quando chamado; S3 só quando o serviço
# :amazon é instanciado; encrypts :token vira no-op).
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

  # Fase 26 (PAIR-06): o webhook autenticado é boot-fatal em produção porque o
  # milestone v1.7 inteiro depende dele (pareamento + estado de conexão).
  Evolution.webhook_hmac_key
  unless Evolution.webhook_base_url.start_with?("https://")
    raise Evolution::Errors::ConfigurationError,
          "EVOLUTION_WEBHOOK_BASE_URL deve começar com https:// — ver 26-RESEARCH.md"
  end

  # INFRA-01: object storage (MinIO/S3). config/storage.yml usa ENV.fetch(_, nil) para não
  # quebrar o boot de test/CI; a exigência real das vars é aqui, em produção.
  %w[S3_ENDPOINT AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].each do |var|
    next if ENV[var].present?

    raise Evolution::Errors::ConfigurationError,
          "#{var} não configurado (variável de ambiente) — object storage indisponível; ver .env.example"
  end
  unless ENV["S3_ENDPOINT"].start_with?("https://")
    raise Evolution::Errors::ConfigurationError,
          "S3_ENDPOINT deve começar com https:// — ver .env.example / 25-RESEARCH.md Pattern 5"
  end

  # active_record_encryption (encrypts :token): as três chaves são obrigatórias em produção —
  # sem elas o token da instância seria persistido em texto claro.
  %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ].each do |var|
    next if ENV[var].present?

    raise Evolution::Errors::ConfigurationError,
          "#{var} não configurado (variável de ambiente) — encrypts :token exige as três chaves; ver .env.example"
  end
end
