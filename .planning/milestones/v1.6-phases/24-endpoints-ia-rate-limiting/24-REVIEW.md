---
phase: 24-endpoints-ia-rate-limiting
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - app/controllers/api/v1/ai/artes_controller.rb
  - app/controllers/api/v1/ai/base_controller.rb
  - app/controllers/api/v1/ai/clients_controller.rb
  - app/serializers/api/v1/ai/arte_serializer.rb
  - config/application.rb
  - config/initializers/rack_attack.rb
  - config/routes.rb
  - test/controllers/api/v1/ai/artes_controller_test.rb
  - test/controllers/api/v1/ai/clients_controller_test.rb
  - test/integration/rack_attack_test.rb
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 24: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Esta fase implementa três endpoints para integração com IA (`GET /api/v1/ai/artes`, `POST /api/v1/ai/artes`, `GET /api/v1/ai/clients/:id/summary`), protegidos por autenticação via API key com prefixo `ak_` e comparação em tempo constante (`secure_compare`). O Rack::Attack está corretamente registrado em `config/application.rb` (linha 39) e as regras de throttle estão configuradas. A lógica de paginação, o serializador e o tratamento de erros seguem os padrões do projeto.

Foi encontrado um defeito crítico de segurança: o throttle de IA aplica-se apenas a requisições que incluem um token válido no header `Authorization`, deixando requisições sem autenticação (ou com bearer vazio) completamente fora do controle de taxa. Há também quatro warnings de robustez e dois itens informativos.

**Nota sobre CR-01 do review anterior (2026-06-12):** O achado anterior apontava que `counts[Arte.statuses["approved"]]` retornaria sempre zero. Esse achado estava INCORRETO. `Arte.statuses["approved"]` retorna o inteiro `1`; `Arte.group(:status).count` com PostgreSQL e coluna `integer` retorna chaves inteiras (`{0=>N, 1=>M, ...}`); portanto `counts[1]` resolve corretamente. O bug não existe.

**Nota sobre CR-02 do review anterior:** O achado anterior afirmava que Rack::Attack não estava registrado no middleware stack. Isso também estava INCORRETO. `config.middleware.use Rack::Attack` está presente em `config/application.rb:39`.

---

## Critical Issues

### CR-01: Throttle de IA não cobre requisições sem autenticação — endpoint exposto a enumeração ilimitada

**File:** `config/initializers/rack_attack.rb:30-34`

**Issue:** O throttle `"api/ai_by_key"` discrimina pelo valor do header `Authorization`:

```ruby
throttle("api/ai_by_key", limit: 60, period: 60) do |req|
  if req.path.start_with?("/api/v1/ai/")
    req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip.presence
  end
end
```

Quando nenhum header `Authorization` é enviado, a expressão retorna `nil` (`.presence` de string vazia também retorna `nil`). O Rack::Attack interpreta `nil` como "não aplicar este throttle". Resultado: um ator externo pode fazer requisições ilimitadas para `/api/v1/ai/*` sem autenticação (recebendo 401 a cada vez) sem nunca ser bloqueado pelo rate limiter. Todos os outros endpoints de login do projeto possuem throttle por IP como segunda camada (ex: `api/admin_login_by_ip`, `api/client_login_by_ip`), mas o namespace de IA não tem essa proteção, ficando exposto a enumeração e ataques de timing não limitados.

**Fix:** Adicionar um throttle por IP como fallback para o namespace de IA, análogo ao padrão já usado nos outros endpoints:

```ruby
# config/initializers/rack_attack.rb — adicionar após o throttle api/ai_by_key existente
throttle("api/ai_by_ip", limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?("/api/v1/ai/")
end
```

Isso garante que mesmo requisições sem credenciais sejam controladas por IP.

---

## Warnings

### WR-01: CORS wildcard `"*"` como default em produção

**File:** `config/application.rb:32`

**Issue:** `origins ENV.fetch("CORS_ORIGINS", "*")` usa `"*"` como fallback. Se a variável `CORS_ORIGINS` não for provisionada no ambiente de produção (erro de deploy, rotação de configuração), todos os endpoints `/api/*` passam a aceitar requisições cross-origin de qualquer domínio. Para um serviço que inclui endpoints de sessão (`/api/v1/admin/session`, `/api/v1/client/session`), um origin wildcard combinado com credenciais é uma configuração insegura — e o default silencioso remove a visibilidade do problema.

**Fix:** Forçar configuração explícita em produção:

```ruby
# config/application.rb
allowed_origins = Rails.env.production? \
  ? ENV.fetch("CORS_ORIGINS")            # levanta KeyError se ausente — falha visível
  : ENV.fetch("CORS_ORIGINS", "http://localhost:3000")

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

### WR-02: `ArtesController#index` — range invertido (`from > to`) retorna silenciosamente zero resultados

**File:** `app/controllers/api/v1/ai/artes_controller.rb:15-17`

**Issue:** Não há validação de que `from <= to`. Quando `from > to` (ex: `?from=2026-12-01&to=2026-01-01`), a query `where(scheduled_on: from..to)` gera um range inverso que o PostgreSQL executa como `BETWEEN '2026-12-01' AND '2026-01-01'` — resultando em zero linhas sem nenhum erro. O cliente de IA recebe uma resposta 200 com `data: []` e não tem como distinguir "nenhuma arte aprovada no período" de "período inválido informado", o que pode introduzir bugs silenciosos no sistema consumidor.

**Fix:**

```ruby
from = Date.parse(params[:from])
to   = Date.parse(params[:to])

if from > to
  render_error(
    code:   "bad_request",
    detail: "O parâmetro 'from' deve ser anterior ou igual a 'to'.",
    status: :bad_request
  )
  return
end

scope = scope.where(scheduled_on: from..to)
```

---

### WR-03: `ArteSerializer#resolve_media_url` — exceção de storage derruba toda a coleção serializada

**File:** `app/serializers/api/v1/ai/arte_serializer.rb:26-32`

**Issue:** `arte.media_file.url` pode lançar exceção dependendo da configuração do serviço de storage (ex: `NotImplementedError` com disk service sem `url_options`, `ActiveStorage::FileNotFoundError`, ou erros de rede em provedores remotos). Esse método é chamado para cada elemento em `serialize_collection`, o que significa que uma única arte com problema no storage interrompe toda a resposta paginada com HTTP 500, em vez de degradar graciosamente.

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

### WR-04: Teste de throttle `"60 primeiras requisições"` verifica apenas a 60ª resposta

**File:** `test/integration/rack_attack_test.rb:52-60`

**Issue:** O teste executa `60.times { ... }` mas chama `assert_not_equal 429, response.status` apenas uma vez, ao final do bloco — verificando somente a última (60ª) resposta. Se qualquer uma das 59 anteriores retornar 429 (por estado de cache poluído de outro teste, por condição de corrida, ou por regressão futura no limite do throttle), o teste passa mesmo assim, mascarando o problema.

**Fix:**

```ruby
test "60 primeiras requisições ao namespace AI não retornam 429" do
  original = ENV["AI_API_KEY"]
  ENV["AI_API_KEY"] = AI_THROTTLE_KEY
  Rack::Attack.cache.store.clear
  60.times do |i|
    get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: ai_auth_headers
    assert_not_equal 429, response.status,
      "Requisição #{i + 1}/60 retornou 429 inesperadamente"
  end
ensure
  ENV["AI_API_KEY"] = original
end
```

---

## Info

### IN-01: Ausência de validação de esquema em `external_url`

**File:** `app/models/arte.rb` (contexto para `app/controllers/api/v1/ai/artes_controller.rb:47`)

**Issue:** O campo `external_url` não possui validação de formato de URI. O endpoint `POST /api/v1/ai/artes` aceita e persiste qualquer string como `external_url` (ex: `"javascript:alert(1)"`, `"file:///etc/passwd"`, strings sem protocolo). O serializer de IA devolve esse valor como `media_url`. Embora Rails 8 proteja contra `javascript:` em `link_to`, o valor não sanitizado é exposto via API e pode ser interpretado por clientes downstream.

**Fix:** Adicionar validação de URI no modelo:

```ruby
# app/models/arte.rb
validates :external_url,
  format: {
    with: /\Ahttps?:\/\/.+/i,
    message: "deve ser uma URL HTTP ou HTTPS válida"
  },
  allow_blank: true
```

---

### IN-02: `rack_attack_test.rb` sem `# frozen_string_literal: true`

**File:** `test/integration/rack_attack_test.rb:1`

**Issue:** Os outros dois arquivos de teste desta fase incluem o magic comment `# frozen_string_literal: true`. O `rack_attack_test.rb` não o inclui, quebrando a consistência do projeto.

**Fix:** Adicionar `# frozen_string_literal: true` como primeira linha do arquivo.

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
