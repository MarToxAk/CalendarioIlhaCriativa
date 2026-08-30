ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
# `Object#stub` (usado em test/models/approval_response_test.rb, arte_test.rb) vem daqui.
# `rails/test_help` carrega o minitest mas não o minitest/mock.
require "minitest/mock"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Ao carregar as fixtures, o Rails tenta desligar a integridade referencial com
    # `ALTER TABLE ... DISABLE TRIGGER ALL`. Isso atinge *system triggers* do PostgreSQL e
    # exige SUPERUSER — ser dono da tabela não basta. Quando o usuário da aplicação não é
    # superusuário (o caso deste PostgreSQL compartilhado), o Rails apenas avisa e segue,
    # inserindo as fixtures em ordem alfabética: `sessions` entra antes de `users` e viola
    # a FK `fk_rails_758836b4f0`, quebrando toda a suíte no `before_setup`.
    #
    # Marcar as FKs como DEFERRABLE INITIALLY DEFERRED exige apenas ser dono da tabela e
    # move a checagem para o COMMIT da transação de fixtures — quando todas as linhas já
    # foram inseridas, independente da ordem.
    #
    # Escopo: SOMENTE o banco de teste, em tempo de execução. `db/schema.rb` e o schema de
    # produção não mudam. Precisa rodar DEPOIS de `rails/test_help` (que recarrega o schema
    # de teste via `maintain_test_schema!`, revertendo estes ALTERs) e também dentro de cada
    # worker paralelo, que tem seu próprio banco.
    def self.defer_foreign_keys_for_fixtures!
      connection = ActiveRecord::Base.connection
      return unless connection.adapter_name == "PostgreSQL"

      non_deferrable = connection.select_all(<<~SQL.squish)
        SELECT conname, conrelid::regclass::text AS table_name
        FROM pg_constraint
        WHERE contype = 'f' AND NOT condeferrable
      SQL

      non_deferrable.each do |row|
        connection.execute(
          "ALTER TABLE #{row["table_name"]} " \
          "ALTER CONSTRAINT #{connection.quote_table_name(row["conname"])} " \
          "DEFERRABLE INITIALLY DEFERRED"
        )
      end
    end

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
    parallelize_setup { defer_foreign_keys_for_fixtures! }

    # Caminho de processo único (abaixo do limiar de paralelização).
    defer_foreign_keys_for_fixtures!

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
