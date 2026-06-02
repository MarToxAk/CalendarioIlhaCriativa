# Calendário de Aprovação de Artes

## What This Is

Sistema web em Ruby on Rails para agências e freelancers de social media gerenciarem o fluxo de aprovação de conteúdo com seus clientes. Cada cliente recebe um link único com senha simples para acessar um calendário mensal, visualizar as artes agendadas por dia e registrar aprovação ou solicitar alterações com comentários. O administrador gerencia todo o processo pelo painel interno.

**v1.0 shipped 2026-05-27** — sistema completo e funcional com todos os 35 requisitos implementados.

**v1.1 em progresso** — Phase 07.1 complete 2026-06-02: CR-01 (set_client guard), CR-02 (destroy feedback), CR-03 (media_source param), WR-01 (radio padrão), WR-02 (botão Editar) corrigidos.

## Core Value

O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.

## Requirements

### Validated (v1.0)

- ✓ Admin pode cadastrar e gerenciar clientes (nome, link, senha) — v1.0 Phase 2
- ✓ Admin pode desativar um cliente (bloqueia acesso ao portal) — v1.0 Phase 2
- ✓ Senha visível na tela do cliente fica correta após edição — v1.0 Phase 2.1
- ✓ Admin pode adicionar artes a dias específicos do calendário (upload direto ou link externo) — v1.0 Phase 3 + 3.1
- ✓ Arte pode ter formato: imagem, vídeo ou texto/legenda — v1.0 Phase 3
- ✓ Arte pode ser marcada para Instagram, Facebook ou LinkedIn — v1.0 Phase 3
- ✓ Cada cliente tem um calendário mensal de artes com link público + senha simples — v1.0 Phase 4
- ✓ Cliente visualiza o calendário com as artes do mês — v1.0 Phase 4
- ✓ Cliente marca cada arte como Aprovado ou Pediu Alteração — v1.0 Phase 5
- ✓ Cliente pode escrever comentário explicando as alterações desejadas — v1.0 Phase 5
- ✓ Admin pode marcar arte como revisada após fazer as alterações — v1.0 Phase 5
- ✓ Admin visualiza todas as respostas dos clientes no painel — v1.0 Phase 6
- ✓ Admin pode filtrar dashboard por cliente e por status — v1.0 Phase 6
- ✓ Admin pode escrever resposta interna a artes com pedido de alteração — v1.0 Phase 6
- ✓ Admin vê histórico de aprovações por cliente — v1.0 Phase 6
- ✓ Cada arte tem data limite de aprovação (prazo) — v1.0 Phase 3

### Active (v1.1)

- [x] Upload de arquivos no model Art funcional (ActiveStorage) — ARTE-08 — Validated in Phase 07.1: media_source param handling (CR-03), radio upload padrão (WR-01), botão Editar expandido (WR-02)
- [ ] client_id sempre associado corretamente ao admin logado ao criar/editar artes — ARTE-09
- [x] Validações e escopos @client consistentes nas queries de Art — ARTE-10 — Validated in Phase 07.1: set_client guard (CR-01) + destroy boolean check (CR-02)

### Backlog (v1.2+)

- [ ] Notificações por e-mail ao admin quando cliente aprova ou pede alteração (NOTF-01)
- [ ] Notificações por e-mail ao cliente quando arte é revisada (NOTF-02)
- [ ] Faixa de resumo no topo do calendário (X aprovados, Y pendentes) (CAL2-01)
- [ ] Exportar relatório de aprovações de um cliente em PDF ou CSV (ADM2-01)
- [ ] Duplicar uma arte para outro cliente ou data (ADM2-02)
- [ ] Deploy em produção com Active Storage S3 (infraestrutura de storage)
- [ ] Sidebar links "Aprovações" e "Calendário" wired (atualmente apontam para `#`)

### Out of Scope

- Login OAuth / conta de cliente — link+senha é suficiente para o perfil de uso
- Integração com APIs de redes sociais (publicação automática) — Meta API exige app review
- App mobile nativo — web-first; mobile responsivo via browser
- Multi-stage workflows — desnecessário para 10-30 clientes
- White-labeling / domínio personalizado — complexidade sem benefício imediato v1
- IA para geração de legendas — fora do escopo de aprovação
- Drag-and-drop de artes no calendário — v2+ UX
- Real-time collaboration — WebSockets desnecessário neste volume

## Context

**Estado atual (v1.0 shipped):**
- Carteira de 10–30 clientes ativos
- Conteúdo para Instagram, Facebook e LinkedIn
- Admin faz upload direto de arquivos OU cola links externos (Google Drive, Dropbox)
- Status simplificado: Pendente → Aprovado / Pediu Alteração → Revisado → Pendente
- Prazo de aprovação por arte (data limite definida pelo admin)
- Notificações: admin verifica o painel quando quiser, sem alertas automáticos
- **Tech stack:** Rails 8.1.3, PostgreSQL (192.168.3.203), Tailwind v4, Stimulus, Turbo, ActiveStorage
- **Codebase:** ~284 arquivos, 26.713+ linhas de código
- **Storage:** ActiveStorage local (upload) + URLs externas (Drive/Dropbox) — S3 para produção

## Constraints

- **Tech Stack**: Ruby on Rails — decisão do usuário
- **Acesso do cliente**: Link único por cliente + senha simples, sem autenticação complexa
- **Storage**: Suporte a upload local e links externos (Drive/Dropbox) para os arquivos
- **Escala**: Projetado para 10–30 clientes simultâneos
- **Deploy**: Infraestrutura local (192.168.3.203) — produção precisará de S3 para storage

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rails como stack | Escolha do usuário | ✓ Bom |
| Link + senha simples para cliente | Evita fricção de cadastro para o cliente | ✓ Bom — funciona para o perfil de uso |
| Status binário (Aprovado/Pediu Alteração) | Mantém o fluxo simples | ✓ Bom — re-aprovação via revised? funciona |
| Sem notificações automáticas v1 | Reduz complexidade inicial | ✓ Bom — admin usa o painel ativo |
| Rails 8 auth generator sem Devise | Auth nativo simples e controlável | ✓ Bom — Session DB-persistida funciona |
| Tailwind v4 CSS-native (@theme) | Versão instalada pela gem tailwindcss-rails 4.x | ✓ Bom — design tokens funcionam |
| Gems em vendor/bundle | bot user não está no grupo rvm | ✓ Necessário |
| scheduled_on :date (não datetime) | Evita problemas de timezone no calendário | ✓ Bom — artes no dia correto |
| Queries sempre escopadas por @client | Previne cross-client data leak | ✓ Seguro — aplicado em todos os controllers |
| has_many :approval_responses | Permite histórico completo por arte | ✓ Correto — re-aprovação funciona |
| Turbo Frame para filtros do dashboard | Filtros sem recarregar a página completa | ✓ UX responsiva |
| Phase 2.1 inserida | password_plain stale após update (bug pós-auditoria) | ✓ CLIE-04 satisfeito |
| Phase 3.1 inserida | form sem client_id — blocker absoluto de criação | ✓ ARTE-01→07 satisfeitos |

## Current Milestone: v1.1 Fix Art Upload & Client Association

**Goal:** Corrigir o upload de arquivos no model Art e garantir que cada arte seja criada com a associação correta ao `@client` do admin logado.

**Target features:**
- Upload funcional via ActiveStorage no model Art (arquivos salvos e acessíveis)
- Associação automática e correta do `client_id` ao criar/editar artes
- Validações e escopos consistentes (`@client` sempre presente nas queries de Art)

---

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---

### History

- 2026-05-27 — v1.0 SHIPPED — todos os 35 requisitos implementados em 3 dias
- Phase 06 complete (2026-05-27) — Painel admin completo com dashboard, filtros Turbo Frame, admin_reply, histórico por cliente
- Phase 02.1 complete (2026-05-27) — Gap password_plain sync fechado
- Phase 03.1 complete (2026-05-27) — Gap criação de artes fechado (client_id, media toggle, sidebar link)
- 2026-06-02 — v1.1 started — Fix Art Upload & Client Association
- Phase 07 complete (2026-06-02) — Proteção cross-client em set_arte (SC3), filtragem por client_id no index (SC4), form condicional com selector/hidden_field e erros :base (ARTE-08, ARTE-09, ARTE-10)

---
*Last updated: 2026-06-02 after Phase 07 complete*
