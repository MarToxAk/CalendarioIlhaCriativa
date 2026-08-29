# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Background jobs in development

Development usa o adapter `solid_queue` para o Active Job (`config.active_job.queue_adapter = :solid_queue`
em `config/environments/development.rb`). Isso torna jobs agendados (`set(wait:)` / `set(wait_until:)`)
duráveis — eles sobrevivem a um restart do `bin/dev`, ao contrário do adapter `:async` (in-process).

- As tabelas `solid_queue_*` vivem na base **`calendario_livia_development`** (dev tem uma base única;
  `config.solid_queue.connects_to` é production-only).
- Rode `bin/setup` uma vez para carregá-las. O passo é idempotente; se preferir rodar à mão:
  `bin/rails runner "load Rails.root.join('db/queue_schema.rb') unless ActiveRecord::Base.connection.table_exists?(:solid_queue_jobs)"`
- `bin/dev` sobe o processo `jobs` (`bin/jobs`, linha `jobs:` no `Procfile.dev`) junto de `web` e `css`.
