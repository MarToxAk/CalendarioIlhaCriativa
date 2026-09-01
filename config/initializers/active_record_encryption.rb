# frozen_string_literal: true

# Chaves do active_record_encryption (encrypts :token em whatsapp_instances) vêm SÓ de
# variável de ambiente (.env / docker-compose) — o fallback automático para
# config/credentials.yml.enc (active_record_encryption.*) foi removido (deploy env-driven).
#
# Este initializer roda durante `load_config_initializers`, ANTES do
# `config.after_initialize` do ActiveRecord::Railtie que efetivamente chama
# `ActiveRecord::Encryption.configure(**config.active_record.encryption.to_h)`.
# Setar as três chaves aqui garante que os valores da ENV são os que valem.
#
# Ausência das vars NÃO é boot-fatal por si só: em test/CI (sem .env, sem essas vars)
# as três ficam nil e o `encrypts` opera como no-op (comportamento pré-migração,
# tokens em texto claro só no banco de teste). O fail-fast de produção — exigir as
# três presentes quando Rails.env.production? — vive em config/initializers/evolution.rb.
Rails.application.configure do
  primary_key         = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
  deterministic_key   = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence
  key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence

  config.active_record.encryption.primary_key         = primary_key         if primary_key
  config.active_record.encryption.deterministic_key   = deterministic_key   if deterministic_key
  config.active_record.encryption.key_derivation_salt = key_derivation_salt if key_derivation_salt
end
