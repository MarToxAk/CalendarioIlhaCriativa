# Retrospective

## Milestone: v1.0 — MVP Calendário de Aprovação de Artes

**Shipped:** 2026-05-27
**Archived:** 2026-06-02
**Phases:** 8 | **Plans:** 23 | **Timeline:** 3 days (2026-05-24 → 2026-05-27)

---

### What Was Built

1. **Rails 8.1.3** com PostgreSQL, Tailwind v4, Rack::Attack e auth generator — fundação sólida em 1 dia
2. **Painel admin completo** — CRUD de clientes, sidebar, rotação de token, copy de link/senha com modal + clipboard
3. **Gestão de artes** — upload direto (ActiveStorage) + link externo, plataforma/formato/prazo, client_id via hidden field contextual
4. **Portal do cliente** — calendário mensal CSS grid 7 colunas, preview imagem/vídeo/legenda, badges de status, navegação por mês
5. **Fluxo de aprovação** — aprovar/pedir alteração via Stimulus sem page reload, re-aprovação após revisão, histórico por arte
6. **Dashboard de feedback** — Turbo Frame filters, admin_reply, histórico de aprovações por cliente

### What Worked

- **Audit-driven gap closure** — executar `/gsd-audit-milestone` antes de completar o milestone revelou 2 bugs críticos (ARTE-01 e CLIE-04) que impediam fluxos essenciais do admin. A inserção das fases 2.1 e 3.1 os fechou cirurgicamente.
- **Decimal phases para gaps** — a convenção de phase 2.1/3.1 para gaps permitiu inserir correções sem renumerar as fases existentes.
- **Code review pós-execução** — a fase 06-04 (criada a partir do `/gsd-code-review`) capturou XSS armazenado (h() em nome de cliente) e risco de HTTP desync (:password_plain em strong params) que não teriam sido encontrados só por testes.
- **Scope discipline** — o projeto manteve foco no fluxo de aprovação. Notificações, OAuth e mobile foram mantidos fora do escopo mesmo com oportunidade de escopo creep.
- **Turbo Frame para filtros** — a escolha de Turbo Frame em vez de fetch/JS puro para os filtros do dashboard foi correta: filtros reais sem overhead de SPA.

### What Was Inefficient

- **REQUIREMENTS.md desatualizado** — após as fases 3.1 e 6, os checkboxes e status da tabela de traceability não foram atualizados. O archive teve que corrigir isso manualmente. Processo: atualizar REQUIREMENTS.md no final de cada fase, não só no milestone.
- **VERIFICATION.md ausente na fase 3** — Phase 3 foi completada sem arquivo de verificação formal. Isso forçou o audit a classificar ARTE-01→09 como "orphaned" mesmo com código correto. Processo: VERIFICATION.md é obrigatório, mesmo para fases pequenas.
- **06-VERIFICATION.md desatualizado** — o arquivo mostrava `gaps_found` do estado pré-Plan 04, nunca re-executado após o gap closure. Processo: re-executar verificação após gap closures.
- **Fases 2.1 e 3.1 não identificadas no audit inicial** — o audit foi feito antes das fases serem inseridas, tornando seu status stale ao momento do archivamento. Considerar marcar o audit como "superseded" quando fases de gap closure são inseridas.

### Patterns Established

- **Rack::Attack desde o dia 1** — proteção brute-force instalada na fundação, não retrofitada depois.
- **Queries escopadas por @client** — padrão de segurança anti-IDOR aplicado em todos os controllers do portal.
- **client.persisted? no _form** — diferencia new/edit sem variável extra no render de partial.
- **find_or_create_by! nos seeds** — seeds idempotentes; re-executar não cria duplicatas.
- **Decimal phase insertion** — fase 2.1, 3.1 para gaps urgentes sem quebrar a sequência principal.

### Key Lessons

1. **Audit antes de completar, não depois** — o audit revelou 2 blockers críticos. Sem ele, o milestone teria "completado" com o fluxo de criação de artes completamente quebrado.
2. **Manter REQUIREMENTS.md sincronizado ao longo das fases** — não deixar para o milestone close.
3. **VERIFICATION.md é obrigatório em todas as fases** — mesmo planos de 1 arquivo precisam de verificação formal para o audit funcionar.
4. **Code review após execução encontra o que testes não encontram** — XSS e HTTP desync passaram por todos os testes funcionais mas foram capturados pelo review.
5. **Gap closures devem atualizar o audit** — se o audit está stale, marcar como superseded ou re-executar.

### Cost Observations

- **Sessions:** ~6 sessões de trabalho
- **Timeline:** 3 dias de 2026-05-24 a 2026-05-27
- **Commits:** 149
- **Velocity:** 23 planos em 3 dias (~7-8 planos/dia)

---

## Cross-Milestone Trends

| Metric | v1.0 |
|--------|------|
| Days to ship | 3 |
| Phases | 8 |
| Plans | 23 |
| Gap phases inserted | 2 |
| Bugs found by audit | 2 critical |
| Bugs found by code review | 2 (XSS + HTTP desync) |
| Requirements coverage | 35/35 |
