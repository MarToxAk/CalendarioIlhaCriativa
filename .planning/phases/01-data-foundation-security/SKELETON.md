# Walking Skeleton — Calendário de Aprovação de Artes

**Phase:** 1 — Data Foundation + Security
**Generated:** 2026-05-24

## Capability Proven End-to-End

O admin consegue fazer login em `/admin/login` com credenciais criadas via seed (escrita real na tabela `sessions` do PostgreSQL, leitura real da tabela `users`), é redirecionado para `/admin/dashboard`, e o `rails server` sobe sem erros com todas as migrações aplicadas.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Rails 8.1.3 | Stack matura, auth generator nativo, Hotwire incluso, Active Storage incluso — sem dependências extras de auth |
| Data layer | PostgreSQL 16 + ActiveRecord | Suporte nativo a índices únicos, transações ACID para rotação de token, tipos `date` sem ambiguidade de timezone |
| Admin auth | Rails 8 auth generator — Session model DB-persistida + cookie HTTP-only assinado | Cookie revogável via `Session.destroy`; sem JWT sem estado; password reset incluso |
| Client auth | has_secure_token (token 24-char no URL) + has_secure_password (senha bcrypt) | Token no URL = link compartilhável; senha = segunda camada sem conta/e-mail; regenerate_access_token automático |
| Rate limiting | Rack::Attack 6.8 — throttle por token + fallback por IP | Gem testada em produção; discriminator por token protege contra IPs dinâmicos; sem Redis necessário em dev |
| Background jobs | GoodJob 4.x (PostgreSQL-backed) | Sem Redis; usa o mesmo Postgres; adequado para volume de 10-30 clientes |
| Frontend | Tailwind CSS (standalone binary) + Hotwire (Turbo + Stimulus) via importmap | Sem Node.js build pipeline; Rails 8 padrão; Turbo para updates parciais sem SPA |
| File storage | Active Storage (incluso no Rails 8) + image_processing 2.x | Uploads locais em dev, S3-compatible em prod; vips para variantes |
| Directory layout | Controllers em namespaces `admin/` e `client/`; base controllers `Admin::BaseController` e `ClientController` | Separação clara de contextos de auth; queries de cliente sempre escopadas via `@client.artes` |
| Deployment target | Local dev com `bin/rails server` | Fase 1 valida a fundação localmente; deploy em produção no milestone v1 |

## Stack Touched in Phase 1

- [x] Project scaffold — `rails new` com PostgreSQL, Tailwind, importmap, sem Thruster
- [x] Routing — `/admin/login` (SessionsController), `/admin/dashboard` (Admin::DashboardController), `/c/:token` (ClientController)
- [x] Database — escrita real em `sessions` no login; leitura real em `users` na autenticação; todas as migrações aplicadas
- [x] UI — formulário de login admin (ERB gerado + personalizado com UI-SPEC) conectado ao banco real
- [x] Deployment — `bin/rails server` sobe sem erros em ambiente de desenvolvimento local

## Out of Scope (Deferred to Later Slices)

- CRUD de clientes no painel admin (Phase 2)
- Formulário de criação de artes (Phase 3)
- Calendário do cliente com artes reais (Phase 4)
- Fluxo de aprovação (Phase 5)
- Dashboard de feedback do admin (Phase 6)
- Envio de e-mail (Action Mailer configurado mas não usado na Phase 1)
- OTP/PIN por e-mail para acesso do cliente (decidido: has_secure_password + senha simples)
- Password reset do admin (gerado pelo auth generator, rota disponível mas não testada nesta fase)
- Deploy em produção / configuração de servidor
- Active Storage em produção (S3, CDN)

## Subsequent Slice Plan

Cada fase posterior adiciona uma fatia vertical sobre este skeleton sem alterar as decisões arquiteturais:

- Phase 2: Admin faz login, cria clientes (CRUD completo) e copia link + senha — UI do painel admin
- Phase 3: Admin cria/edita/exclui artes com upload de arquivo ou link externo, define prazo e plataforma
- Phase 4: Cliente acessa portal pelo link único, autentica com senha simples, vê calendário mensal com artes
- Phase 5: Cliente aprova artes ou pede alteração com comentário; re-aprovação após revisão do admin
- Phase 6: Admin vê dashboard de respostas de todos os clientes, filtra, marca como revisado
