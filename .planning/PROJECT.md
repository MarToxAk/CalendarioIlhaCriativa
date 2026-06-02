# Calendário de Aprovação de Artes

## What This Is

Sistema web em Ruby on Rails para agências e freelancers de social media gerenciarem o fluxo de aprovação de conteúdo com seus clientes. Cada cliente recebe um link único com senha simples para acessar um calendário mensal, visualizar as artes agendadas por dia e registrar aprovação ou solicitar alterações com comentários. O administrador gerencia todo o processo pelo painel interno.

**v1.0 shipped 2026-05-27** — sistema completo e funcional com todos os 35 requisitos implementados.

**v1.1 shipped 2026-06-02** — upload via ActiveStorage funcional, associação correta de cliente ao criar artes, proteção cross-client, rádio de mídia honrado no controller, feedback de destroy, e consistência SSR no formulário.

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

### Validated (v1.1)

- ✓ Upload de arquivos no model Art funcional via ActiveStorage — ARTE-08 — v1.1 Phase 7 + 7.1
- ✓ Arte não pode ser criada sem client_id válido — selector condicional garante associação correta — ARTE-09 — v1.1 Phase 7
- ✓ set_arte/set_client garantem que arte pertence ao cliente esperado, evitando acesso cross-client — ARTE-10 — v1.1 Phase 7 + 7.1

### Backlog (v1.2+)

- [ ] Notificações por e-mail ao admin quando cliente aprova ou pede alteração (NOTF-01)
- [ ] Notificações por e-mail ao cliente quando arte é revisada (NOTF-02)
- [ ] Faixa de resumo no topo do calendário (X aprovados, Y pendentes) (CAL2-01)
- [ ] Exportar relatório de aprovações de um cliente em PDF ou CSV (ADM2-01)
- [ ] Duplicar uma arte para outro cliente ou data (ADM2-02)
- [ ] Deploy em produção com Active Storage S3 (INFRA-01)
- [ ] Sidebar links "Aprovações" e "Calendário" wired (atualmente apontam para `#`) (INFRA-02)

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

**Estado atual (v1.1 shipped 2026-06-02):**
- Carteira de 10–30 clientes ativos
- Conteúdo para Instagram, Facebook e LinkedIn
- Admin faz upload direto de arquivos OU cola links externos (Google Drive, Dropbox)
- Status simplificado: Pendente → Aprovado / Pediu Alteração → Revisado → Pendente
- Prazo de aprovação por arte (data limite definida pelo admin)
- Notificações: admin verifica o painel quando quiser, sem alertas automáticos
- **Tech stack:** Rails 8.1.3, PostgreSQL (192.168.3.203), Tailwind v4, Stimulus, Turbo, ActiveStorage
- **Codebase:** ~290 arquivos, ~27.000+ linhas de código
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
| set_arte usa @client.artes.find quando @client presente | Escopo por associação levanta RecordNotFound automaticamente para cross-client | ✓ Seguro — ARTE-10 satisfeito |
| Phase 07.1 inserida pós-fase 7 | Code review encontrou 3 issues críticos + 2 UX gaps | ✓ CR-01..CR-03 + WR-01..WR-02 corrigidos |
| uploadField SSR usa mesma lógica do radio | Evita estado contraditório (radio checked + campo hidden) sem JavaScript | ✓ WR-01 resolvido completamente |

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
- Phase 07.1 complete (2026-06-02) — CR-01 (set_client guard), CR-02 (destroy feedback), CR-03 (media_source param), WR-01 (radio padrão + SSR fix), WR-02 (botão Editar expandido)
- 2026-06-02 — v1.1 SHIPPED — 3 requisitos (ARTE-08, ARTE-09, ARTE-10) validados

---
*Last updated: 2026-06-02 after v1.1 milestone shipped*
