# Phase 01: Data Foundation + Security — Research

**Pesquisado:** 2026-05-24
**Domínio:** Rails 8.1.3 — setup do projeto, auth generator, migrações, has_secure_token, Rack::Attack, rotação de token
**Confiança geral:** HIGH (stack core verificada no RubyGems.org; padrões de auth verificados na documentação oficial do Rails)

---

## Resumo

Esta fase cria o alicerce sobre o qual todo o resto do projeto depende. Ela não entrega nenhuma UI visível para o cliente — entrega o projeto Rails criado, os três modelos de domínio com migrações corretas, os primitivos de autenticação configurados e a proteção contra brute-force ativa antes de qualquer código de aplicação.

A decisão mais crítica — usar `has_secure_token` para o token do cliente e o auth generator nativo do Rails 8 para o admin — está completamente alinhada com o que o Rails oferece de fábrica. Nenhum gem de auth adicional é necessário. O risco principal desta fase é errar nos tipos de coluna (datetime em vez de date para `scheduled_on`) ou esquecer os índices únicos no token — ambos são fáceis de fazer e caros de reverter depois que dados de produção existem.

O Walking Skeleton desta fase é: projeto criado, banco configurado, `rails db:migrate` roda sem erro, o admin consegue fazer login via `/admin/login` com credenciais criadas via seed, e a tentativa de senha do cliente é bloqueada após 5 falhas em 20 segundos.

**Recomendação principal:** Criar o app com `rails new calendario_livia --database=postgresql --css=tailwind --javascript=importmap`, rodar `bin/rails generate authentication` imediatamente, adaptar para admin-only (sem rota de sign-up), criar as três migrações na ordem Client → Arte → ApprovalResponse, configurar Rack::Attack, e semear um admin via `rails console`.

---

<phase_requirements>
## Phase Requirements

| ID | Descrição | Suporte da Pesquisa |
|----|-----------|---------------------|
| AUTH-01 | Admin pode criar conta e fazer login com email e senha | Rails 8 auth generator gera User + Session + concern Authentication; seed cria o admin |
| AUTH-02 | Admin pode fazer logout da sessão | SessionsController#destroy gerado pelo auth generator; destrói Session record e limpa cookie |
| AUTH-03 | Cada cliente tem um link público único (token de 24 chars) para acessar o próprio calendário | `has_secure_token :access_token` no modelo Client; SecureRandom.base58(24) automático |
| AUTH-04 | Cliente precisa digitar uma senha simples ao acessar o link pela primeira vez na sessão | `has_secure_password` no modelo Client; ClientController#require_client_auth verifica session[:client_id] |
| AUTH-05 | Admin pode rotacionar o token de um cliente (gera novo link, invalida o anterior e a sessão existente) | `client.regenerate_access_token` + verificação de token na sessão do cliente a cada request |
| AUTH-06 | Cliente pode fazer logout do portal | Client::SessionsController#destroy; limpa session[:client_id] e session[:client_token_version] |
</phase_requirements>

---

## Mapa de Responsabilidades Arquiteturais

| Capacidade | Tier Primário | Tier Secundário | Racional |
|------------|--------------|-----------------|----------|
| Auth do admin (email + senha) | API / Backend (Rails controller) | — | Session-based auth via cookie; lógica em controller concern |
| Auth do cliente (token + senha) | API / Backend (Rails controller) | — | Token no URL + session cookie; validado a cada request no before_action |
| Geração e rotação de token | Database / Storage (ActiveRecord) | — | `has_secure_token` gera e persiste o token; `regenerate_access_token` atualiza no DB |
| Proteção brute-force | API / Backend (Rack middleware) | — | Rack::Attack intercepta antes do controller |
| Schema de dados | Database / Storage (PostgreSQL) | — | Migrações definem tipos, índices, constraints |
| Formulário de login admin | Frontend Server (Rails view) | — | ERB gerado pelo auth generator; sem JS framework |
| Formulário de senha do cliente | Frontend Server (Rails view) | — | ERB custom no Client::SessionsController |

---

## 1. Setup do Projeto Rails 8

### Comando Exato de Criação

```bash
rails new calendario_livia \
  --database=postgresql \
  --css=tailwind \
  --javascript=importmap \
  --skip-thruster
```

**Flags explicadas:**
- `--database=postgresql` — configura `pg` gem e `database.yml` para PostgreSQL [VERIFIED: rubygems.org]
- `--css=tailwind` — instala `tailwindcss-rails` gem (standalone binary, sem Node) [VERIFIED: rubygems.org]
- `--javascript=importmap` — mantém importmap (padrão Rails 8, sem build pipeline) [VERIFIED: rails guides]
- `--skip-thruster` — pula o proxy HTTP/2 Thruster; irrelevante para dev local [VERIFIED: rails guides]
- Hotwire (Turbo + Stimulus) é incluído **por padrão** no Rails 8 — nenhum flag necessário [VERIFIED: rails guides]
- Active Storage é incluído **por padrão** no Rails 8 — nenhum flag necessário [VERIFIED: rails guides]

### Passos Imediatos Pós-criação

```bash
cd calendario_livia

# 1. Configurar credenciais do banco em config/database.yml
# 2. Criar banco
bin/rails db:create

# 3. Configurar timezone em config/application.rb
# config.time_zone = 'Brasilia'
# config.active_record.default_timezone = :local

# 4. Instalar gems adicionais (ver seção Gemfile)
bundle install

# 5. Rodar auth generator (ver seção 2)
bin/rails generate authentication

# 6. Criar migrações dos modelos de domínio (ver seção 3)
bin/rails db:migrate

# 7. Iniciar servidor
bin/rails server
```

---

## 2. Rails 8 Auth Generator — Admin

### Comando Exato

```bash
bin/rails generate authentication
```

[VERIFIED: guides.rubyonrails.org, bigbinary.com/blog]

### O que é Gerado

| Arquivo | Propósito |
|---------|-----------|
| `app/models/user.rb` | Modelo admin com `has_secure_password` |
| `app/models/session.rb` | Sessão do admin com `has_secure_token` |
| `app/models/current.rb` | Estado por-request (`Current.session`, `Current.user`) |
| `app/controllers/concerns/authentication.rb` | Concern com `require_authentication`, `start_new_session_for`, `terminate_session` |
| `app/controllers/sessions_controller.rb` | new / create / destroy |
| `app/controllers/passwords_controller.rb` | Fluxo de reset de senha |
| `app/mailers/passwords_mailer.rb` | Mailer de reset de senha |
| `app/views/sessions/new.html.erb` | Formulário de login |
| `app/views/passwords/` | Views de reset de senha |
| `db/migrate/xxx_create_users.rb` | Tabela users: email_address, password_digest |
| `db/migrate/xxx_create_sessions.rb` | Tabela sessions: user_id FK, token, ip_address, user_agent |
| `test/mailers/previews/passwords_mailer_preview.rb` | Preview do mailer |

### Como Funciona o Mecanismo de Sessão

O Rails 8 auth generator usa **Session model persistido no DB**, não apenas `session[:user_id]`:

1. Login → cria um `Session` record no banco → armazena o token em cookie assinado (HTTP-only, Secure)
2. Cada request → concern `Authentication` valida o cookie → busca `Session` no DB → define `Current.session` e `Current.user`
3. Logout → destrói o `Session` record → cookie se torna inválido

**Implicação para este projeto:** Admin usa `Current.user` e `Current.session`, não `session[:user_id]` diretamente. O concern gerado é o mecanismo correto — não reimplementar. [VERIFIED: bigbinary.com/blog, andriifurmanets.com]

### Adaptação para Admin-Only (sem sign-up público)

O generator não cria rota de sign-up. A adaptação necessária é apenas:

```ruby
# config/routes.rb — o generator adiciona automaticamente:
resources :sessions, only: [:new, :create, :destroy]
resources :passwords, only: [:new, :create, :edit, :update]
# NÃO adicionar: resources :users (sem sign-up público)

# Mover rotas do admin para namespace:
namespace :admin do
  root to: "dashboard#index"
  resources :clients
  # etc.
end
```

```ruby
# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  before_action :require_authentication
  # require_authentication é do concern gerado — use sem modificar
end
```

O admin único é criado via seed ou `rails console`:

```ruby
# db/seeds.rb
User.find_or_create_by!(email_address: "admin@ilhacriativa.com.br") do |u|
  u.password = "SenhaSegura123!"
  u.password_confirmation = "SenhaSegura123!"
end
```

[VERIFIED: andriifurmanets.com, bigbinary.com/blog]

---

## 3. Schema do Banco — Migrações Exatas

### 3.1 Migration: Create Clients

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_clients.rb
class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string  :name,           null: false
      t.string  :access_token,   null: false
      t.string  :password_digest, null: false
      t.boolean :active,         null: false, default: true

      t.timestamps
    end

    add_index :clients, :access_token, unique: true
  end
end
```

**Campos explicados:**
- `name` — nome do cliente, obrigatório
- `access_token` — token de 24 chars gerado por `has_secure_token`; índice único é a garantia de unicidade no DB
- `password_digest` — bcrypt hash da senha simples; gerado por `has_secure_password`
- `active` — flag para desativação do cliente (CLIE-03, fase futura); inclua agora para não migrar depois

[ASSUMED: o campo `active` antecipa CLIE-03 da fase 2; inclui-lo na fase 1 evita migração posterior em tabela com dados de produção]

### 3.2 Migration: Create Artes

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_artes.rb
class CreateArtes < ActiveRecord::Migration[8.1]
  def change
    create_table :artes do |t|
      t.references :client, null: false, foreign_key: true

      t.string  :title
      t.text    :caption
      t.date    :scheduled_on,       null: false   # date (não datetime) — sem ambiguidade de timezone
      t.date    :approval_deadline
      t.string  :external_url                       # link Google Drive / Dropbox (nullable)

      # Enum columns — integer-backed, null: false, default definido no model
      t.integer :platform,   null: false, default: 0  # instagram=0, facebook=1, linkedin=2
      t.integer :media_type, null: false, default: 0  # image=0, video=1, caption_only=2
      t.integer :status,     null: false, default: 0  # pending=0, approved=1, change_requested=2, revised=3

      t.timestamps
    end

    # Índice composto — query do calendário sempre filtra por client_id + scheduled_on
    add_index :artes, [:client_id, :scheduled_on]
    add_index :artes, :status
  end
end
```

**Decisão crítica: `scheduled_on :date` (não `datetime`)**

Uma coluna `date` não tem informação de timezone. Um campo `datetime` em UTC pode virar um dia diferente em Brasília (UTC-3) quando convertido. Para este projeto, a hora do dia é irrelevante — o admin agenda para uma data. Usar `date` elimina a classe inteira de bugs de timezone para este campo.

[VERIFIED: PITFALLS.md do projeto — pitfall #5 documentado e confirmado]

### 3.3 Migration: Create Approval Responses

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_approval_responses.rb
class CreateApprovalResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_responses do |t|
      t.references :arte, null: false, foreign_key: true

      t.integer  :decision,     null: false  # approved=0, change_requested=1
      t.text     :comment                    # nullable — obrigatório só quando change_requested
      t.datetime :responded_at

      t.timestamps
    end

    add_index :approval_responses, :arte_id, unique: true  # uma resposta ativa por arte (v1)
    add_index :approval_responses, :decision
  end
end
```

**Nota:** O índice único em `arte_id` reforça "uma resposta ativa por arte" no nível de DB para v1. Se histórico multi-resposta for necessário em v2, remover o unique e usar `has_many` no modelo Arte.

---

## 4. Modelos — Código Exato

### 4.1 Client Model

```ruby
# app/models/client.rb
class Client < ApplicationRecord
  has_secure_token :access_token   # gera token de 24 chars base58 via SecureRandom.base58(24)
                                   # método regenerate_access_token gerado automaticamente
  has_secure_password              # cria authenticate(password), password_digest column
                                   # validação de presença incluída por padrão

  has_many :artes, dependent: :destroy

  validates :name, presence: true
  validates :access_token, presence: true, uniqueness: true

  # Para AUTH-04: verificar se a sessão do cliente ainda corresponde ao token atual
  # (proteção contra rotação — ver seção 6)
  def token_version
    # Primeiros 8 chars do access_token como versão — muda a cada regeneração
    access_token&.first(8)
  end
end
```

**has_secure_token — como funciona:**
- Gerado automaticamente em `before_create` (padrão Rails 7.1+: `after_initialize`)
- Usa `SecureRandom.base58(24)` — 24 chars do alfabeto base58 (sem 0, O, l, I para legibilidade)
- Método `regenerate_access_token` gerado automaticamente — atualiza e salva no DB via `update!`
- Colisões são "altamente improváveis" — mas o índice único no DB é a rede de segurança real

[VERIFIED: api.rubyonrails.org/classes/ActiveRecord/SecureToken]

**has_secure_password — como funciona:**
- Adiciona `password` e `password_confirmation` como atributos virtuais
- Armazena o bcrypt hash em `password_digest`
- Método `authenticate(password)` retorna o objeto ou `false`
- Validação de presença incluída; validação de comprimento mínimo NÃO incluída (adicionar manualmente)

[VERIFIED: guides.rubyonrails.org/security.html]

### 4.2 Arte Model

```ruby
# app/models/arte.rb
class Arte < ApplicationRecord
  belongs_to :client
  has_one    :approval_response, dependent: :destroy
  has_one_attached :media_file   # Active Storage; nil se external_url for usado

  enum :platform,   { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
  enum :media_type, { image: 0, video: 1, caption_only: 2 }
  enum :status,     { pending: 0, approved: 1, change_requested: 2, revised: 3 }

  validates :scheduled_on, presence: true
  validates :platform,     presence: true
  validates :media_type,   presence: true
  validates :client,       presence: true

  validate :media_source_present
  validate :only_one_media_source

  private

  def media_source_present
    return if media_file.attached? || external_url.present?
    errors.add(:base, "Precisa de arquivo ou link externo")
  end

  def only_one_media_source
    return unless media_file.attached? && external_url.present?
    errors.add(:base, "Use arquivo OU link externo, não ambos")
  end
end
```

**Nota sobre enums:** Nunca reordenar as chaves do enum — o Rails mapeará os inteiros no DB para os novos labels e corromperá dados. Sempre append ao final ao adicionar novos valores. [VERIFIED: ARCHITECTURE.md do projeto]

### 4.3 ApprovalResponse Model

```ruby
# app/models/approval_response.rb
class ApprovalResponse < ApplicationRecord
  belongs_to :arte

  enum :decision, { approved: 0, change_requested: 1 }

  validates :decision, presence: true
  validate  :arte_must_be_pending, on: :create

  after_create :sync_arte_status

  private

  def arte_must_be_pending
    errors.add(:arte, "já foi respondida") unless arte.pending?
  end

  def sync_arte_status
    case decision
    when "approved"          then arte.approved!
    when "change_requested"  then arte.change_requested!
    end
  end
end
```

---

## 5. Rack::Attack — Configuração Exata

### Instalação

```ruby
# Gemfile
gem "rack-attack", "~> 6.8"
```

```bash
bundle install
```

[VERIFIED: rubygems.org — rack-attack 6.8.0, publicado 2025-10-14, 140M downloads, github.com/rack/rack-attack]

### Initializer

```ruby
# config/initializers/rack_attack.rb

class Rack::Attack
  # Em test, desabilitar (ou usar MemoryStore para não precisar de Redis/cache real)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

  # =========================================================
  # THROTTLE 1: Tentativas de senha no portal do cliente
  # Endpoint: POST /c/:token/session (ou POST /c/:token/login)
  # Regra: 5 tentativas por token por 20 segundos
  # =========================================================
  throttle("client_portal/password_by_token", limit: 5, period: 20) do |req|
    if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
      # Discriminator: o token na URL (não o IP, para cobrir IPs dinâmicos)
      req.path.match(%r{\A/c/([^/]+)/})[1]
    end
  end

  # THROTTLE 2: Fallback por IP (defesa em profundidade)
  throttle("client_portal/password_by_ip", limit: 10, period: 60) do |req|
    req.ip if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
  end

  # =========================================================
  # THROTTLE 3: Login do admin
  # Endpoint: POST /session (ou POST /admin/session)
  # =========================================================
  throttle("admin/login_by_ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/session" && req.post?
  end

  # =========================================================
  # THROTTLE 4: Enumeração de tokens (GET no portal do cliente)
  # Sem senha ainda — limitar tentativas de adivinhar tokens
  # =========================================================
  throttle("client_portal/token_enum_by_ip", limit: 20, period: 60) do |req|
    req.ip if req.path.match?(%r{\A/c/[^/]+\z}) && req.get?
  end

  # =========================================================
  # Resposta customizada para 429 (HTML para portal do cliente)
  # =========================================================
  Rack::Attack.throttled_responder = lambda do |request|
    [
      429,
      { "Content-Type" => "text/html; charset=utf-8" },
      ["<h1>Muitas tentativas</h1><p>Aguarde alguns instantes antes de tentar novamente.</p>"]
    ]
  end
end
```

**Por que throttle por token (não só por IP):**
O token está no URL (enviado por WhatsApp/email). Um atacante que conhece o token pode usar múltiplos IPs. O discriminator deve ser o token para proteger cada link individualmente. [VERIFIED: PITFALLS.md do projeto — pitfall #2; ttb.software/2026/03/21]

**Ajuste de rota:** O caminho exato (`/c/:token/session` vs `/c/:token/login`) depende do routing final. O regex `%r{\A/c/[^/]+/(?:session|login)\z}` cobre ambas as possibilidades. Ajustar quando as rotas forem definidas.

---

## 6. Rotação de Token (AUTH-05)

### Como Regenerar o Token

O `has_secure_token` gera automaticamente o método `regenerate_access_token`:

```ruby
# No controller do admin (Admin::ClientsController ou equivalente)
def rotate_token
  @client = Client.find(params[:id])
  @client.regenerate_access_token
  # → Atualiza access_token no DB com novo valor de 24 chars
  # → O token anterior deixa de existir no banco
  redirect_to admin_client_path(@client), notice: "Link rotacionado com sucesso."
end
```

[VERIFIED: api.rubyonrails.org/classes/ActiveRecord/SecureToken — método regenerate_X gerado automaticamente]

### Como Invalidar a Sessão Existente do Cliente

Simplesmente regenerar o token não invalida sessões abertas — o cliente que estava logado ainda tem `session[:client_id]` válido. Para invalidar:

**Estratégia: armazenar uma "versão do token" na sessão no momento do login, e verificar a cada request.**

```ruby
# app/controllers/client_controller.rb (base controller para portal do cliente)
class ClientController < ApplicationController
  skip_before_action :require_authentication  # pular auth do admin

  before_action :load_client_from_token
  before_action :require_client_auth

  private

  def load_client_from_token
    @client = Client.find_by!(access_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Link inválido", status: :not_found
  end

  def require_client_auth
    # Verifica se está logado E se o token ainda é o mesmo de quando logou
    unless session[:client_id] == @client.id &&
           session[:client_token_version] == @client.token_version
      session.delete(:client_id)
      session.delete(:client_token_version)
      redirect_to client_login_path(token: @client.access_token)
    end
  end
end
```

```ruby
# app/controllers/client/sessions_controller.rb
class Client::SessionsController < ClientController
  skip_before_action :require_client_auth, only: [:new, :create]

  def new
    # Formulário de senha
  end

  def create
    if @client.authenticate(params[:password])
      session[:client_id]            = @client.id
      session[:client_token_version] = @client.token_version  # ← armazena versão atual
      redirect_to client_calendar_path(token: @client.access_token)
    else
      flash.now[:alert] = "Senha incorreta. Tente novamente."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:client_id)
    session.delete(:client_token_version)
    redirect_to client_login_path(token: @client.access_token), notice: "Saiu com sucesso."
  end
end
```

**Efeito da rotação:** Quando o admin chama `client.regenerate_access_token`, o `token_version` do cliente muda. Na próxima request do cliente com sessão antiga, `session[:client_token_version]` (`"abc12345"`) não bate com `@client.token_version` (`"xyz98765"`) — a sessão é destruída e o cliente é redirecionado para o login. [VERIFIED: unagisoftware.com — padrão de invalidação de sessão via token de versão]

---

## 7. Walking Skeleton — Definição

O Walking Skeleton desta fase é a menor fatia end-to-end que comprova que a fundação funciona:

| Marco | Verificação |
|-------|-------------|
| `rails new` executado | `bin/rails server` sobe sem erro |
| `bin/rails db:migrate` | Cria tabelas clients, artes, approval_responses, users, sessions sem erro |
| Seed executado | Admin criado: `User.count == 1` |
| GET `/admin/login` | Retorna 200, mostra formulário de login |
| POST `/admin/login` com credenciais corretas | Redireciona para `/admin/dashboard` (ou root do admin) |
| POST `/admin/login` com credenciais erradas | Retorna 200 com mensagem de erro |
| Rack::Attack ativo | 6ª tentativa de POST em `/c/TOKEN/session` retorna 429 |
| `Client.create!` funciona | Token de 24 chars gerado automaticamente |
| `client.regenerate_access_token` | Retorna true, token muda no DB |

Não é necessário ter UI do cliente ou calendário funcionando. Esta fase termina quando: migrations rodaram, admin faz login, e Rack::Attack bloqueia brute-force.

---

## 8. Gems a Adicionar

### Gemfile Completo para esta Fase

```ruby
ruby "3.3.3"  # versão instalada no ambiente [VERIFIED: ruby --version]

gem "rails",  "~> 8.1.3"    # [VERIFIED: rubygems.org — v8.1.3, 746M downloads]
gem "pg",     "~> 1.5"      # [VERIFIED: rubygems.org]
gem "puma",   ">= 5.0"      # [VERIFIED: bundled with Rails]

# Frontend
gem "turbo-rails"            # [VERIFIED: bundled with Rails 8]
gem "stimulus-rails"         # [VERIFIED: bundled with Rails 8]
gem "tailwindcss-rails"      # [VERIFIED: rubygems.org — v4.4.0, 15M downloads, github.com/rails/tailwindcss-rails]

# Autenticação e segurança
gem "bcrypt", "~> 3.1"       # [VERIFIED: rubygems.org — v3.1.22, 388M downloads, github.com/bcrypt-ruby/bcrypt-ruby]
gem "rack-attack", "~> 6.8"  # [VERIFIED: rubygems.org — v6.8.0, 140M downloads, github.com/rack/rack-attack]

# Storage e processamento
gem "image_processing", "~> 1.2"  # [VERIFIED: rubygems.org — v2.0.1, 109M downloads, github.com/janko/image_processing]

# Domain gems (incluir desde a fase 1 para não reabrir Gemfile/bundle install depois)
gem "simple_calendar", "~> 3.1"   # [VERIFIED: rubygems.org — v3.1.0, 6M downloads, publicado 2025-01-09]
gem "pagy", "~> 9.3"              # [VERIFIED: rubygems.org — v43.5.5, 38M downloads, github.com/ddnexus/pagy]
gem "good_job", "~> 4.0"          # [VERIFIED: rubygems.org — v4.18.2, 7M downloads, github.com/bensheldon/good_job]
gem "active_storage_validations"  # [VERIFIED: rubygems.org — v3.0.5, 26M downloads, github.com/igorkasyanchuk/active_storage_validations]

gem "dotenv-rails", groups: [:development, :test]

group :development, :test do
  gem "debug", platforms: %i[mri mswin]
  gem "brakeman"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end
```

**Nota sobre `image_processing`:** A gem `image_processing` v2.x (lançada 2024) usa `vips` por padrão. A versão 1.x usava ImageMagick. Rails Active Storage usa `image_processing` para variantes. Verificar se `libvips` está disponível no servidor. Em desenvolvimento, o processamento de variantes é lazy e não bloqueia.

---

## Auditoria de Legitimidade dos Gems

> Nota: `slopcheck` opera sobre PyPI (Python). Gems Ruby são verificados via RubyGems.org API, que é o registry autoritativo para Ruby.

| Gem | Registry | Versão | Downloads | Source Repo | Verificação | Disposição |
|-----|----------|--------|-----------|-------------|-------------|------------|
| rack-attack | RubyGems | 6.8.0 | 140M | github.com/rack/rack-attack | RubyGems API | Aprovado |
| good_job | RubyGems | 4.18.2 | 7.4M | github.com/bensheldon/good_job | RubyGems API | Aprovado |
| simple_calendar | RubyGems | 3.1.0 | 6M | github.com/excid3/simple_calendar | RubyGems API | Aprovado |
| active_storage_validations | RubyGems | 3.0.5 | 26M | github.com/igorkasyanchuk/active_storage_validations | RubyGems API | Aprovado |
| tailwindcss-rails | RubyGems | 4.4.0 | 15M | github.com/rails/tailwindcss-rails | RubyGems API | Aprovado |
| pagy | RubyGems | 43.5.5 | 38M | github.com/ddnexus/pagy | RubyGems API | Aprovado |
| bcrypt | RubyGems | 3.1.22 | 388M | github.com/bcrypt-ruby/bcrypt-ruby | RubyGems API | Aprovado |
| image_processing | RubyGems | 2.0.1 | 109M | github.com/janko/image_processing | RubyGems API | Aprovado |

**Gems removidos por SLOP:** nenhum
**Gems flagged como suspeitos:** nenhum

*slopcheck não suporta RubyGems (apenas PyPI/npm). Verificação manual via RubyGems.org API confirma que todos os gems existem, têm volume de downloads significativo, têm repositório público verificável, e são publicados por mantenedores reconhecidos no ecossistema Rails.*

---

## Padrões de Arquitetura

### Diagrama de Fluxo de Dados — Fase 1

```
[Admin Browser]
    │
    ▼ POST /session (email + senha)
[SessionsController#create]
    │ User.authenticate_by(email:, password:)
    │ → start_new_session_for(user)
    │       → Session.create! (token no DB)
    │       → cookies.signed[:session_id] = session.id
    ▼
[Current.session = Session] → [Current.user = User]
    │
    ▼ before_action :require_authentication
[Admin routes protegidas]


[Cliente Browser]
    │
    ▼ GET /c/:token
[load_client_from_token]
    │ Client.find_by!(access_token: params[:token])
    ▼
    │ [session[:client_id] existe?]
    │   → NÃO → redirect → POST /c/:token/session (senha)
    │                 ↓ [Rack::Attack throttle: 5/20s por token]
    │                 ↓ client.authenticate(params[:password])
    │                 ↓ session[:client_id] = client.id
    │                 ↓ session[:client_token_version] = client.token_version
    │   → SIM → [token_version bate?]
    │               → NÃO → destruir sessão → redirect login
    │               → SIM → acesso liberado
    ▼
[Portal do cliente]


[Admin rotaciona token]
    │
    ▼ PATCH /admin/clients/:id/rotate_token
[client.regenerate_access_token]
    │ → novo access_token no DB
    │ → token_version muda
    ▼
[Próxima request do cliente: session[:client_token_version] != client.token_version]
    │
    ▼ Sessão destruída → redirect para novo link
```

### Estrutura de Pastas Recomendada (Fase 1)

```
app/
├── controllers/
│   ├── admin/
│   │   ├── base_controller.rb        # before_action :require_authentication
│   │   └── dashboard_controller.rb   # placeholder para walking skeleton
│   ├── client/
│   │   └── sessions_controller.rb    # new / create / destroy (AUTH-04, AUTH-06)
│   ├── client_controller.rb          # base: load_client_from_token + require_client_auth
│   ├── concerns/
│   │   └── authentication.rb         # gerado pelo auth generator (admin)
│   └── sessions_controller.rb        # gerado pelo auth generator (admin)
├── models/
│   ├── client.rb                     # has_secure_token + has_secure_password
│   ├── arte.rb                       # enums + validações
│   ├── approval_response.rb          # enum decision + sync callback
│   ├── current.rb                    # gerado pelo auth generator
│   ├── session.rb                    # gerado pelo auth generator (admin Session)
│   └── user.rb                       # gerado pelo auth generator (admin User)
├── views/
│   ├── admin/
│   │   └── dashboard/
│   │       └── index.html.erb        # placeholder "Admin funcionando"
│   ├── client/
│   │   └── sessions/
│   │       └── new.html.erb          # formulário de senha do cliente
│   └── sessions/
│       └── new.html.erb              # formulário de login admin (gerado)
config/
├── initializers/
│   └── rack_attack.rb               # throttles definidos
├── application.rb                    # config.time_zone = 'Brasilia'
└── routes.rb
db/
├── migrate/
│   ├── xxx_create_users.rb
│   ├── xxx_create_sessions.rb
│   ├── xxx_create_clients.rb
│   ├── xxx_create_artes.rb
│   └── xxx_create_approval_responses.rb
└── seeds.rb                          # admin user seed
```

---

## O que NÃO Construir

| Problema | Não Construir | Usar em Vez | Por que |
|----------|--------------|-------------|---------|
| Auth do admin | Implementação custom com `session[:user_id]` | Rails 8 auth generator (`require_authentication` concern) | O generator cria Session persistido no DB, password reset, cookie HTTP-only — muito mais robusto |
| Geração de token único | UUID ou `SecureRandom.hex` | `has_secure_token :access_token` | Collision handling automático, método regenerate automático, 24 chars base58 |
| Hash de senha | SHA256, MD5 ou armazenar em texto | `has_secure_password` (bcrypt) | bcrypt tem custo adaptativo; SHA256/MD5 são quebráveis por GPU em segundos |
| Rate limiting | Counter em Redis / tabela DB | `rack-attack` gem | Edge cases de concorrência são difíceis; rack-attack é testado em produção em milhares de apps |
| State machine | AASM gem | Rails enum + bang methods | Para 4 estados com 5 transições, enum é suficiente; AASM adiciona DSL e dependência sem ganho |

---

## Pitfalls Críticos para Esta Fase

### Pitfall 1: `datetime` em vez de `date` para `scheduled_on`
**O que acontece:** Arte agendada para Segunda 23h no admin aparece na Terça para o cliente (UTC+0 vs Brasília UTC-3).
**Como evitar:** Usar `t.date :scheduled_on, null: false` na migração. Uma coluna `date` não tem timezone. [VERIFIED: PITFALLS.md, pitfall #5]
**Warning:** Migrar `datetime` para `date` em produção com dados existentes requer cuidado. Decidir correto desde o início.

### Pitfall 2: Esquecer o índice único em `access_token`
**O que acontece:** `has_secure_token` gerencia colisões via Ruby, mas sem índice DB, duas transações simultâneas podem gerar o mesmo token. Também: queries de `Client.find_by(access_token:)` são lentas sem índice.
**Como evitar:** `add_index :clients, :access_token, unique: true` na migração. [VERIFIED: api.rubyonrails.org]

### Pitfall 3: Rotas do portal do cliente no path errado para o Rack::Attack
**O que acontece:** Se a rota de login do cliente for `/c/:token/login` mas o throttle esperar `/c/:token/session`, o throttle não dispara.
**Como evitar:** Definir as rotas ANTES de configurar os paths no Rack::Attack. O regex `%r{\A/c/[^/]+/(?:session|login)\z}` cobre ambos, mas validar contra o `bin/rails routes` final.

### Pitfall 4: Auth generator cria rotas fora do namespace `/admin`
**O que acontece:** O generator adiciona `/session` e `/passwords` na raiz. O admin pode ou não querer isso.
**Como evitar:** Revisar `config/routes.rb` após o `generate authentication` e mover ou prefixar as rotas conforme o design de routing.

### Pitfall 5: `session[:client_token_version]` não implementado na sessão de login
**O que acontece:** Admin rotaciona o token, mas o cliente com sessão aberta continua acessando indefinidamente.
**Como evitar:** No `Client::SessionsController#create`, sempre setar `session[:client_token_version] = @client.token_version`. No `ClientController#require_client_auth`, sempre verificar. [VERIFIED: unagisoftware.com — padrão de invalidação instantânea]

---

## Exemplos de Código Verificados

### has_secure_token com column customizada
```ruby
# Fonte: api.rubyonrails.org/classes/ActiveRecord/SecureToken
class Client < ApplicationRecord
  has_secure_token :access_token   # → cria regenerate_access_token
  has_secure_token :auth_token, length: 36  # comprimento customizável (mínimo 24)
end

client = Client.create!(name: "Acme", password: "senha123")
client.access_token          # => "pX27zsMN2ViQKta1bGfLmVJE"  (24 chars base58)
client.regenerate_access_token  # => true (atualiza no DB)
client.access_token          # => "tU9bLuZseefXQ4yQxQo8wjtB"  (novo token)
```

### has_secure_password autenticação
```ruby
# Fonte: guides.rubyonrails.org/security.html
client = Client.find_by(access_token: "pX27zsMN2ViQKta1bGfLmVJE")
client.authenticate("senha_errada")  # => false
client.authenticate("senha123")      # => client (o objeto)
```

### Rack::Attack throttle por path regex
```ruby
# Fonte: ttb.software/2026/03/21, wafris.org/guides/ultimate-guide-to-rack-attack
throttle("client_portal/password_by_token", limit: 5, period: 20) do |req|
  if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
    req.path.match(%r{\A/c/([^/]+)/})[1]  # extrai token do URL como discriminator
  end
end
```

### Configuração de timezone
```ruby
# config/application.rb
config.time_zone = 'Brasilia'
config.active_record.default_timezone = :local
# Nunca usar Time.now — sempre usar Time.current ou Time.zone.now
# Nunca usar Date.today — sempre usar Date.current
```

### Invalidação de sessão por rotação de token
```ruby
# Fonte: unagisoftware.com/articles/invalidate-user-sessions-rails-instantly/
# No login:
session[:client_token_version] = @client.token_version  # ex: "pX27zsMN"

# No before_action de cada request autenticada:
unless session[:client_token_version] == @client.token_version
  reset_session
  redirect_to client_login_path(token: @client.access_token)
end

# Após rotate:
@client.regenerate_access_token  # token_version agora é diferente
# → próxima request do cliente com sessão antiga será rejeitada
```

---

## Divergência UI-SPEC vs Decisões Arquiteturais

A UI-SPEC v1.1 (seção 4.2) descreve o fluxo do cliente como **"PIN de 6 dígitos enviado por e-mail"** — um magic link / OTP por e-mail.

As **decisões arquiteturais confirmadas** (ARCHITECTURE.md, STACK.md, STATE.md, REQUIREMENTS.md) descrevem o fluxo como **"senha simples digitada pelo cliente, definida e gerenciada pelo admin"** via `has_secure_password`.

**Esses dois designs são incompatíveis.** O OTP por e-mail requer:
- Envio de e-mail (Action Mailer configurado)
- Armazenamento de OTP temporário (coluna na DB ou cache)
- Lógica de expiração
- Interface de reenvio (cooldown de 60s)

A arquitetura `has_secure_password` (AUTH-04) é:
- Senha definida pelo admin ao criar o cliente
- Cliente digita a senha no formulário
- Sem envio de e-mail, sem OTP

**Para o planner:** Esta pesquisa segue as decisões arquiteturais do ARCHITECTURE.md (has_secure_password + senha definida pelo admin). A UI-SPEC do fluxo do cliente precisará ser revisada ou a decisão arquitetural alterada antes de implementar. AUTH-04 conforme especificado nos requisitos ("senha simples ao acessar o link") é compatível com has_secure_password — o OTP da UI-SPEC é uma expansão não requerida pelos requisitos.

[ASSUMED: A UI-SPEC do portal do cliente (seção 4.2 — PIN/OTP) será tratada como aspiracional para v2 e não implementada nesta fase]

---

## Arquitetura de Validação

### Framework de Testes
| Propriedade | Valor |
|-------------|-------|
| Framework | Minitest (padrão Rails 8) |
| Config | `test/test_helper.rb` (gerado) |
| Comando rápido | `bin/rails test` |
| Suite completa | `bin/rails test && bin/rails test:system` |

### Mapa Requisito → Teste

| ID | Comportamento | Tipo de Teste | Comando |
|----|--------------|---------------|---------|
| AUTH-01 | Admin faz login com email/senha corretos | Integration | `bin/rails test test/controllers/sessions_controller_test.rb` |
| AUTH-01 | Admin não entra com senha errada | Integration | mesmo arquivo |
| AUTH-02 | Logout destrói a sessão | Integration | `bin/rails test test/controllers/sessions_controller_test.rb` |
| AUTH-03 | Client criado ganha token de 24 chars | Unit | `bin/rails test test/models/client_test.rb` |
| AUTH-03 | Token é único (índice DB) | Unit | mesmo arquivo |
| AUTH-04 | Cliente com token válido e senha correta: acesso concedido | Integration | `bin/rails test test/controllers/client/sessions_controller_test.rb` |
| AUTH-04 | Cliente com senha errada: acesso negado | Integration | mesmo arquivo |
| AUTH-05 | Rotação gera novo token | Unit | `bin/rails test test/models/client_test.rb` |
| AUTH-05 | Sessão com token antigo é invalidada após rotação | Integration | `bin/rails test test/controllers/client/sessions_controller_test.rb` |
| AUTH-06 | Logout do cliente limpa sessão | Integration | mesmo arquivo |
| Rack::Attack | 6ª tentativa em 20s retorna 429 | Integration | `bin/rails test test/integration/rack_attack_test.rb` |
| Cross-client | Cliente A não acessa arte de cliente B | Integration | `bin/rails test test/integration/client_isolation_test.rb` |
| Migrations | `db:migrate` roda sem erro | (verificação manual / CI) | `bin/rails db:migrate` |

### Gaps do Wave 0 (arquivos a criar)

- [ ] `test/models/client_test.rb` — cobre AUTH-03 e AUTH-05 (unit tests)
- [ ] `test/models/arte_test.rb` — cobre validações de enum e media_source
- [ ] `test/controllers/sessions_controller_test.rb` — cobre AUTH-01 e AUTH-02
- [ ] `test/controllers/client/sessions_controller_test.rb` — cobre AUTH-04, AUTH-05, AUTH-06
- [ ] `test/integration/rack_attack_test.rb` — cobre throttle de brute-force
- [ ] `test/integration/client_isolation_test.rb` — cobre proteção cross-client

---

## Disponibilidade do Ambiente

| Dependência | Requerida Por | Disponível | Versão | Fallback |
|-------------|--------------|------------|--------|----------|
| Ruby 3.3.x | Rails 8.1.3 | Sim (3.3.3) | 3.3.3 | — |
| Rails 8.1.3 | Projeto | Sim | 8.1.3 | — |
| PostgreSQL | Banco de dados | Sim | 16.14 | — |
| rack-attack gem | Brute-force protection | Sim (6.7.0 instalada, 6.8.0 no registry) | 6.7.0 → 6.8.0 | — |
| Node.js | Tailwind (se cssbundling) | Sim (v22.20.0) | 22.20.0 | tailwindcss-rails usa standalone binary, sem Node |
| ctx7 | Documentação de bibliotecas | Não | — | WebFetch para docs oficiais (usado) |

**Nota:** `tailwindcss-rails` usa o binary standalone do Tailwind CSS — Node.js não é necessário. A disponibilidade de Node é irrelevante para esta stack.

---

## Domínio de Segurança

### Categorias ASVS Aplicáveis

| Categoria ASVS | Aplica | Controle |
|----------------|--------|----------|
| V2 Autenticação | Sim | Rails 8 auth generator (admin); has_secure_password + token URL (cliente) |
| V3 Gerenciamento de Sessão | Sim | Session model DB-persistida (admin); session cookie para cliente + verificação de versão de token |
| V4 Controle de Acesso | Sim | `require_authentication` (admin); `require_client_auth` + `@client.artes.find()` (cliente) |
| V5 Validação de Input | Sim | Rails strong parameters; validações de modelo para enums e presença |
| V6 Criptografia | Sim | bcrypt via has_secure_password (fator de custo adaptativo); nunca SHA256/MD5 |

### Padrões de Ameaça Conhecidos

| Padrão | STRIDE | Mitigação |
|--------|--------|-----------|
| Brute-force no login do cliente | Força Bruta | Rack::Attack: 5 tentativas / 20s por token |
| Enumeração de tokens de 24 chars | Divulgação de Info | Token base58 24-char: espaço de busca 58^24 ≈ 10^42; Rack::Attack no GET |
| Acesso cross-client via URL manipulation | Violação de Privilégio | `@client.artes.find(params[:id])` — RecordNotFound em cross-client |
| Session fixation após rotação de token | Elevação de Privilégio | `session[:client_token_version]` verificado a cada request |
| Timing attack na comparação de senha | Divulgação de Info | bcrypt.authenticate é timing-safe por design; não comparar digests manualmente |

---

## Log de Premissas

| # | Premissa | Seção | Risco se Errado |
|---|---------|-------|-----------------|
| A1 | A UI-SPEC (seção 4.2 — OTP/PIN por e-mail) é aspiracional e não será implementada nesta fase | Divergência UI-SPEC | Se o usuário exigir OTP, serão necessários Action Mailer, lógica de OTP, e campo na DB — fora do escopo da fase 1 |
| A2 | Campo `active` na tabela clients (para CLIE-03, fase 2) é incluído na migração da fase 1 para evitar migração futura em tabela com dados | Schema — Migration Clients | Sem risco prático — apenas uma coluna extra nullable com default true |
| A3 | Rota de login do cliente usa o path `/c/:token/session` ou `/c/:token/login` — o regex do Rack::Attack cobre ambos | Rack::Attack | Se o path final for diferente, o throttle não dispara — verificar com `bin/rails routes` |
| A4 | `image_processing` v2.x (que usa vips por padrão, não ImageMagick) é compatível com o ambiente — libvips disponível | Gemfile | Se vips não estiver disponível, ActiveStorage variants falharão silenciosamente |

---

## Perguntas em Aberto (RESOLVIDAS)

1. **Rota de login do cliente: `/c/:token/session` ou `/c/:token/login`?**
   - **RESOLVIDO:** Plano 01-05 escolhe `resource :session, only: [:new, :create, :destroy], controller: 'client/sessions'` → path `POST /c/:token/session`. Rack::Attack configurado com regex que cobre ambos (`session|login`) no plano 01-04.

2. **Confirmação da UI-SPEC do portal do cliente:**
   - **RESOLVIDO:** UI-SPEC seção 4.2 foi corrigida (PIN/OTP removido) — agora descreve senha simples com `has_secure_password`, consistente com AUTH-04. Implementação no plano 01-05 usa senha simples.

---

## Fontes

### Primárias (confiança HIGH)
- RubyGems.org API — verificação de versão e downloads de todos os gems
- `api.rubyonrails.org/classes/ActiveRecord/SecureToken` — has_secure_token syntax, regenerate method
- `guides.rubyonrails.org/security.html` — has_secure_password, session security
- `bigbinary.com/blog/rails-8-introduces-a-basic-authentication-generator` — arquivos gerados pelo auth generator
- `andriifurmanets.com/blogs/built-in-authentication-in-rails` — Session model, Authentication concern, mecanismo de cookie

### Secundárias (confiança MEDIUM)
- `ttb.software/2026/03/21/rails-rate-limiting-rack-attack-production-guide/` — Rack::Attack syntax, dual-discriminator pattern
- `wafris.org/guides/ultimate-guide-to-rack-attack` — setup, throttle por path, RSpec testing pattern
- `unagisoftware.com/articles/invalidate-user-sessions-rails-instantly/` — session token version invalidation pattern
- `jacopretorius.net/2025/05/all-rails-new-options.html` — flags do `rails new` para Rails 8

### Terciárias (confiança LOW — confirmadas por outras fontes)
- `.planning/research/ARCHITECTURE.md` — decisões arquiteturais do projeto (confirmadas pelo projeto)
- `.planning/research/PITFALLS.md` — pitfalls documentados no projeto (confirmados por sources externas)

---

## Metadados

**Confiança por área:**
- Setup do projeto (rails new, flags): HIGH — verificado contra guides oficiais e jacopretorius.net
- Auth generator: HIGH — verificado contra bigbinary.com e andriifurmanets.com
- Schema (campos, tipos, índices): HIGH — derivado de ARCHITECTURE.md do projeto + Rails conventions
- has_secure_token / has_secure_password: HIGH — verificado contra api.rubyonrails.org
- Rack::Attack config: MEDIUM — sintaxe verificada contra docs oficiais e dois guias de produção
- Rotação de token: MEDIUM — padrão verificado contra unagisoftware.com; implementação específica inferida
- Walking Skeleton: HIGH — critérios baseados nas success criteria do ROADMAP.md

**Data da pesquisa:** 2026-05-24
**Válida até:** 2026-07-24 (stack estável; verificar versões de gems antes de criar Gemfile)
