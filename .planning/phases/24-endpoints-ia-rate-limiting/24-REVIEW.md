---
phase: 24-endpoints-ia-rate-limiting
reviewed: 2026-06-12T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - app/controllers/api/v1/ai/base_controller.rb
  - app/controllers/api/v1/ai/artes_controller.rb
  - app/controllers/api/v1/ai/clients_controller.rb
  - app/serializers/api/v1/ai/arte_serializer.rb
  - config/routes.rb
  - config/initializers/rack_attack.rb
  - test/controllers/api/v1/ai/artes_controller_test.rb
  - test/controllers/api/v1/ai/clients_controller_test.rb
  - test/integration/rack_attack_test.rb
findings:
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-06-12
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Esta fase implementa três endpoints para integração com IA (`GET /api/v1/ai/artes`, `POST /api/v1/ai/artes`, `GET /api/v1/ai/clients/:id/summary`) protegidos por autenticação via API key com prefixo `ak_` e comparação em tempo constante, além de throttle via Rack::Attack. A autenticação e o throttle estão bem construídos. Porém, foram encontrados três defeitos críticos: o mais grave é um bug lógico no `ClientsController#summary` que faz com que todos os contadores retornem zero em produção; os outros dois são riscos de segurança — ausência de registro do middleware Rack::Attack e wildcard CORS sem restrição por ambiente. Há ainda quatro warnings de qualidade e robustez.

---

## Critical Issues

### CR-01: `ClientsController#summary` — todos os contadores sempre retornam zero

**File:** `app/controllers/api/v1/ai/clients_controller.rb:8-13`

**Issue:** A query `Arte.where(client_id: client.id).group(:status).count` retorna um hash com **chaves inteiras** (vindas do banco), pois a coluna `status` é `integer` no schema (`t.integer "status"`). As enumerações do ActiveRecord **não traduzem** as chaves do resultado de `group().count` para os labels string do enum. O código acessa o hash com chaves string como `counts["approved"]`, que sempre retorna `nil` — portanto `.to_i` sempre retorna `0`. O campo `total` ainda é correto (`.values.sum` soma os valores inteiros), mas todos os campos individuais (`approved_count`, `pending_count`, `change_requested_count`, `revised_count`) serão sempre `0`. O teste `GET /summary counts são corretos` em `clients_controller_test.rb:78` falha silenciosamente se o banco de testes não mapeá-los corretamente.

**Fix:** Usar os valores inteiros do enum como chaves, ou usar escopo por status separado:

```ruby
# Opção 1: usar as chaves inteiras do enum
STATUS_KEYS = Arte.statuses  # => { "pending" => 0, "approved" => 1, ... }

counts = Arte.where(client_id: client.id).group(:status).count
# counts => { 0 => 2, 1 => 1 }

approved_count         = counts[Arte.statuses["approved"]].to_i
pending_count          = counts[Arte.statuses["pending"]].to_i
change_requested_count = counts[Arte.statuses["change_requested"]].to_i
revised_count          = counts[Arte.statuses["revised"]].to_i

# Opção 2: mais legível — contar por escopo
base = Arte.where(client_id: client.id)
approved_count         = base.approved.count
pending_count          = base.pending.count
change_requested_count = base.change_requested.count
revised_count          = base.revised.count
total                  = base.count
```

---

### CR-02: Rack::Attack não está registrado no middleware stack

**File:** `config/initializers/rack_attack.rb:1` / `config/application.rb`

**Issue:** O arquivo `config/initializers/rack_attack.rb` **configura** as regras da `Rack::Attack`, mas em nenhum lugar do projeto o middleware é **inserido no stack**. `rack-attack` só intercepta requisições se `config.middleware.use Rack::Attack` (ou equivalente) for chamado. O Rails não adiciona gems de middleware automaticamente pelo simples fato de estarem no `Gemfile`. Sem o registro, nenhuma das regras de throttle está ativa em produção — o endpoint de IA pode ser chamado sem limite de taxa.

A verificação foi feita: nenhum `config.middleware.use Rack::Attack` existe em `config/application.rb`, `config/environments/production.rb`, `config/environments/development.rb` ou em qualquer initializer.

**Fix:** Adicionar em `config/application.rb` (ou em um initializer carregado antes dos throttles):

```ruby
# config/application.rb — dentro do bloco class Application
config.middleware.use Rack::Attack
```

Ou no initializer, antes de qualquer configuração de regras:

```ruby
# config/initializers/rack_attack.rb — primeira linha após o require (se necessário)
Rails.application.config.middleware.use Rack::Attack
```

---

### CR-03: CORS com wildcard `*` sem restrição por ambiente

**File:** `config/application.rb:32`

**Issue:** A configuração CORS usa `origins ENV.fetch("CORS_ORIGINS", "*")`. O default `"*"` permite requisições cross-origin de qualquer domínio para **todos** os endpoints `/api/*`, incluindo os endpoints de IA. Em produção, se a variável `CORS_ORIGINS` não for definida no ambiente de deploy (configuração omitida, erro de provisionamento), qualquer site poderá fazer requisições autenticadas ao namespace de IA, contornando intenções de acesso restrito. O risco é particularmente relevante porque a API key de IA é uma credencial estática — um vazamento combinado com CORS aberto amplifica o impacto.

**Fix:** Falhar de forma segura em produção: não ter um default inseguro.

```ruby
# config/application.rb
allowed_origins = if Rails.env.production?
  ENV.fetch("CORS_ORIGINS") # levanta KeyError se não definido — forçando configuração explícita
else
  ENV.fetch("CORS_ORIGINS", "http://localhost:3000")
end

config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins allowed_origins
    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :patch, :put, :delete, :options, :head ]
  end
end
```

---

## Warnings

### WR-01: `ArtesController#index` — sem validação de intervalo de datas `from > to`

**File:** `app/controllers/api/v1/ai/artes_controller.rb:15-17`

**Issue:** O código parseia `from` e `to` mas não verifica se `from <= to`. Quando `from > to`, a query `where(scheduled_on: from..to)` gera um range inverso que retorna zero resultados sem nenhum erro, comportamento silencioso que pode confundir consumidores da API.

**Fix:**

```ruby
from = Date.parse(params[:from])
to   = Date.parse(params[:to])

if from > to
  render_error(code: "bad_request", detail: "O parâmetro 'from' deve ser anterior ou igual a 'to'.", status: :bad_request)
  return
end

scope = scope.where(scheduled_on: from..to)
```

---

### WR-02: `Rack::Attack` — cache store não configurado para desenvolvimento

**File:** `config/initializers/rack_attack.rb:2`

**Issue:** O cache store do Rack::Attack é configurado explicitamente apenas em `Rails.env.test?` (`MemoryStore`). Em desenvolvimento, `config.cache_store = :memory_store` está definido, mas o Rack::Attack usa `Rails.cache` por padrão — o que em desenvolvimento é `ActiveSupport::Cache::NullStore` (valor padrão do `config.cache_store` em desenvolvimento não garante funcionar para throttle). Se o desenvolvedor quiser testar throttle localmente, as regras não funcionarão de forma confiável, podendo mascarar problemas de configuração.

**Fix:** Configurar explicitamente o cache para o desenvolvimento também:

```ruby
# config/initializers/rack_attack.rb
if Rails.env.test?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
elsif Rails.env.development?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end
# Em produção, Rack::Attack usa Rails.cache (solid_cache) automaticamente
```

---

### WR-03: `ENV["AI_API_KEY"]` mutado em testes com workers paralelos

**File:** `test/controllers/api/v1/ai/artes_controller_test.rb:9-10` / `test/controllers/api/v1/ai/clients_controller_test.rb:9-10`

**Issue:** `test_helper.rb` configura `parallelize(workers: :number_of_processors)`. Ambos os arquivos de teste mutam `ENV["AI_API_KEY"]` no `setup` e o restauram no `teardown`. `ENV` é um hash global de processo — com múltiplos workers em threads no mesmo processo, a mutação de `ENV["AI_API_KEY"]` em um worker pode interferir com outro, causando falhas intermitentes de autenticação em testes que rodam concorrentemente.

**Fix:** Usar `stub_const` ou `ClimateControl` para variáveis de ambiente, ou garantir que cada worker roda em processo separado (o padrão do Rails com `parallelize` é forked processes, não threads — mas vale documentar ou usar uma fixture de credentials em vez de ENV).

Se o paralelismo for com processos (fork), não há race condition; mas se for threads, há. Confirmar o modo e adicionar um comentário ou usar uma abordagem thread-safe:

```ruby
# Opção thread-safe: usar Rails credentials stub em vez de ENV mutation
# Ou: garantir Rails.application.credentials stubbing
```

---

### WR-04: `ArteSerializer#resolve_media_url` — sem tratamento de erro para URL do ActiveStorage

**File:** `app/serializers/api/v1/ai/arte_serializer.rb:27-31`

**Issue:** `arte.media_file.url` pode lançar exceção dependendo da configuração do storage service (e.g., `ActiveStorage::FileNotFoundError` ou erro de rede em serviço remoto). O método `resolve_media_url` é chamado durante a serialização da coleção em `serialize_collection`, o que significa que uma única arte com problema no storage pode derrubar toda a resposta paginada, retornando 500 em vez de degradar graciosamente.

**Fix:**

```ruby
private_class_method def self.resolve_media_url(arte)
  if arte.media_file.attached?
    arte.media_file.url
  else
    arte.external_url
  end
rescue => e
  Rails.logger.error("ArteSerializer: falha ao resolver URL da mídia para arte##{arte.id}: #{e.message}")
  nil
end
```

---

## Info

### IN-01: Constante `AI_API_KEY` duplicada em dois arquivos de teste com o mesmo nome

**File:** `test/controllers/api/v1/ai/artes_controller_test.rb:6` / `test/controllers/api/v1/ai/clients_controller_test.rb:6`

**Issue:** Ambos os arquivos definem a constante `AI_API_KEY` no nível da classe de teste (não dentro de uma instância). Embora ambas sejam classes distintas e não haja colisão real de constantes de Ruby neste contexto (pois estão em namespaces de classe diferentes), o valor gerado por `SecureRandom.hex(8)` é diferente em cada arquivo pois são avaliados em momentos distintos. É uma prática que pode causar confusão na leitura e manutenção.

**Fix:** Extrair para um módulo de helper de teste compartilhado ou usar uma constante compartilhada em `test_helper.rb`:

```ruby
# test/test_helpers/ai_api_key_helper.rb
module AiApiKeyHelper
  AI_API_KEY = "ak_test_fixed_for_tests"
end
```

---

### IN-02: `rack_attack_test.rb` sem `# frozen_string_literal: true`

**File:** `test/integration/rack_attack_test.rb:1`

**Issue:** Os outros dois arquivos de teste desta fase incluem o magic comment `# frozen_string_literal: true` (linhas 1 de ambos). O `rack_attack_test.rb` não o inclui, quebrando a consistência do projeto.

**Fix:** Adicionar `# frozen_string_literal: true` como primeira linha do arquivo.

---

_Reviewed: 2026-06-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
