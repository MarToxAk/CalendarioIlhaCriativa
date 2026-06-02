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

## Milestone: v1.1 — Fix Art Upload & Client Association

**Shipped:** 2026-06-02
**Phases:** 2 (07 + 07.1) | **Plans:** 5 | **Timeline:** 1 dia

---

### What Was Built

1. **set_arte + @client disponível** — `@client = @arte.client` eliminando risco de NoMethodError nas views
2. **Selector condicional de cliente** — hidden_field quando client_id presente, f.select quando não, com erros :base visíveis
3. **Proteção cross-client** — `@client.artes.find` levanta RecordNotFound automaticamente; index filtrado por client_id
4. **set_client guard (CR-01)** — redirect com alert quando client_id presente mas cliente não existe
5. **destroy com feedback booleano (CR-02)** — notice de sucesso vs. alert de falha baseado no retorno real
6. **media_source honrado no controller (CR-03)** — purge_later condicional para upload→link; external_url zerando para link→upload
7. **Radio upload pré-selecionado + SSR fix (WR-01)** — div uploadField usa mesma condição que o radio
8. **Botão Editar expandido (WR-02)** — visible para pending, revised e change_requested

### What Worked

- **Code review como driver de fase** — as 3 issues críticas e 2 UX gaps do `/gsd-code-review` se tornaram uma fase inteira (07.1). O processo de review pós-execução continua comprovando valor.
- **Verificação automática + UAT manual** — a separação clara entre o que pode ser verificado por grep/testes e o que precisa de servidor rodando foi eficiente. 4 testes manuais cobrindo os cenários que realmente importam.
- **Inserção de fase decimal para urgências** — Phase 07.1 foi inserida sem retrabalho de numeração. Padrão consolidado.
- **TDD para 07.1** — RED/GREEN por task produziu 26 testes, 65 assertions, cobertura completa dos behaviors do controller.

### What Was Inefficient

- **VERIFICATION.md com status `human_needed` não atualizado após UAT** — o status permaneceu `human_needed` após o UAT manual passar. O processo precisa de um passo explícito de "fechar VERIFICATION.md após UAT completo".
- **UAT herdado de fases v1.0 aberto no milestone v1.1** — fases 02, 03.1, 05 foram arquivadas mas seus HUMAN-UAT.md ficaram como `partial`. Ao fechar v1.1, o audit os surfacou como itens abertos. Processo: marcar fases históricas como `partial-archived` ao arquivar milestone.
- **Inconsistência SSR no WR-01** — a lógica do radio foi corrigida (fase 07.1) mas a div de upload não foi alinhada na mesma fase. Isso exigiu um fix adicional no momento do fechamento do milestone.

### Patterns Established

- **uploadField SSR = mesma condição do radio** — `(attached? || external_url.blank?)` como lógica unificada para evitar estado contraditório sem JS.
- **Milestone audit de verificações v1.x ao fechar v1.x+1** — itens `human_needed` de fases antigas precisam ser deferred explicitamente, não ignorados.

### Key Lessons

1. **Fechar VERIFICATION.md imediatamente após UAT** — não deixar `human_needed` aberto quando o UAT já validou os testes.
2. **Alinhar SSR e lógica de radio na mesma fase** — qualquer mudança em `checked:` deve auditar o `class hidden` correspondente.
3. **26 testes TDD em 1 sessão** — TDD com RED/GREEN por behavior é viável mesmo para controllers Rails densos. Custo baixo, cobertura alta.

### Cost Observations

- **Sessions:** ~2 sessões de trabalho
- **Timeline:** 1 dia (2026-06-02)
- **Commits:** ~53 (pós-v1.0)
- **Velocity:** 5 planos em 1 dia

---

## Cross-Milestone Trends

| Metric | v1.0 | v1.1 |
|--------|------|------|
| Days to ship | 3 | 1 |
| Phases | 8 | 2 |
| Plans | 23 | 5 |
| Gap phases inserted | 2 | 1 |
| Bugs found by audit | 2 critical | 0 |
| Bugs found by code review | 2 (XSS + HTTP desync) | 3 critical + 2 UX |
| Requirements coverage | 35/35 | 3/3 |
| TDD coverage | partial | 26 tests, 65 assertions |
