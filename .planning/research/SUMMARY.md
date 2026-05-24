# Research Summary: Calendário de Aprovação de Artes

## Recommended Stack

- **Rails 8.1.3** — versão estável atual; usa o auth generator nativo (sem Devise)
- **PostgreSQL** — banco principal com suporte a índices compostos para queries de calendário
- **Hotwire (Turbo + Stimulus)** — frontend padrão Rails 8; suficiente para aprovação inline e navegação de calendário sem React
- **Active Storage** — upload de arquivos; coluna `external_url :string` para links externos (Drive/Dropbox)
- **active_storage_validations** — validação de tamanho e MIME type no modelo
- **simple_calendar (v3.1.0)** — gem de calendário mensal, compatível com Rails 8, evita construir o grid do zero
- **Rack::Attack** — throttling de tentativas de senha (proteção ao acesso do cliente)
- **good_job** — background jobs sobre PostgreSQL (sem Redis)
- **Tailwind CSS** — estilização (padrão Rails 8)

## Table Stakes Features (v1)

### Lado do Cliente
- Visualizar calendário mensal de artes com navegação de mês
- Ver preview da arte (imagem, vídeo, legenda) com ícone da plataforma
- Ver prazo de aprovação e status atual de cada arte
- Marcar arte como **Aprovado** ou **Pediu Alteração**
- Escrever comentário explicando as alterações desejadas

### Lado do Admin
- CRUD de clientes (nome, link, senha)
- Adicionar artes a dias do calendário (upload direto ou link externo)
- Definir plataforma (Instagram, Facebook, LinkedIn), formato e prazo
- **Dashboard de respostas** — visão unificada de todos os clientes com status e comentários
- Ação "Marcar como Revisado" após fazer as alterações pedidas

## Architecture Overview

### Componentes
- **Painel Admin** — rota `/admin/`, auth via Rails 8 generator, `Admin::BaseController`
- **Portal do Cliente** — rota `/c/:token/`, auth via token + senha, `ClientController`
- **Core de Domínio** — 3 modelos: `Client`, `Arte`, `ApprovalResponse`
- **Storage** — Active Storage (arquivos) + coluna `external_url` (links externos)

### Modelo de Dados
- `Client`: `has_secure_token :access_token`, `has_secure_password`, nome, senhas gerenciadas pelo admin
- `Arte`: enum `platform` (instagram/facebook/linkedin), enum `media_type` (image/video/caption_only), enum `status` (pending/approved/change_requested/revised), `scheduled_on :date`, `approval_deadline :date`, `external_url :string`, `has_one_attached :media_file`
- `ApprovalResponse`: `belongs_to :arte`, enum `decision`, `comment :text` (opcional)

### Controle de Acesso
- Admin: `session[:user_id]` via Rails 8 auth generator
- Cliente: `session[:client_id]` + verificação do token no URL a cada request
- Isolamento: toda query no ClientController via `@client.artes.find(...)`, nunca `Arte.find(...)`

## Critical Pitfalls to Avoid

1. **Timezone** — usar `config.time_zone = 'Brasilia'` e coluna `date` (não `datetime`) para `scheduled_on`; senão artes aparecem no dia errado
2. **Cross-client leak** — sempre escopar queries pelo `@client`; nunca `Arte.find(params[:id])` em controllers do cliente
3. **Brute force no token + senha** — Rack::Attack desde o Phase 1; token de 24 chars com `has_secure_token`
4. **State corruption** — usar enum bang methods (`arte.approved!`), nunca `update(status: params[:status])`
5. **Upload sem validação** — `active_storage_validations` para MIME type real (magic bytes) e limite de tamanho; vídeos em background job

## Build Order Recommendation

| Fase | Foco | Por que essa ordem |
|------|------|-------------------|
| 1 | Data Foundation + Segurança | Tudo depende do modelo correto desde o início |
| 2 | Admin Auth + CRUD de Clientes | Precisa existir antes de criar artes |
| 3 | CRUD de Artes + Upload | Depende dos clientes existirem |
| 4 | Portal do Cliente + Auth | Depende das artes existirem para exibir |
| 5 | Fluxo de Aprovação | Depende do portal estar funcionando |
| 6 | Painel de Feedback do Admin | Depende das aprovações existirem |
| 7 | Polish + Prazos + Mobile | Layer de UX sobre funcionalidade completa |

## Key Decisions Validated by Research

| Decisão | Validação |
|---------|-----------|
| Rails como stack | Alta compatibilidade com o domínio; auth generator nativo resolve admin |
| Link + senha simples (sem OAuth) | Padrão validado por ferramentas como Gain; menor fricção = maior adoção pelo cliente |
| Status binário (Aprovado / Pediu Alteração) | Workflows multi-estágio são feature de enterprise; binário é padrão em ferramentas como Planable e Gain |
| Sem notificações automáticas v1 | Reduz complexidade sem impacto real para 10-30 clientes |
| Sem integração com APIs das redes sociais | Meta API exige app review e refresh de tokens; armadilha de complexidade que atrasa v1 |

---
*Gerado em: 2026-05-24 após pesquisa de domínio*
