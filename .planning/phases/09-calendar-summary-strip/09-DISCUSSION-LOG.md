# Phase 9: Calendar Summary Strip - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 09-calendar-summary-strip
**Areas discussed:** Escopo das contagens, Status exibidos, Layout visual da faixa, Texto mobile, Atualização após aprovação (SC4), Partial vs inline

---

## Escopo das contagens

### O que a faixa deve contar como "artes do mês"?

| Option | Description | Selected |
|--------|-------------|----------|
| Só o mês corrente | Conta artes com scheduled_on entre 1º e último dia do mês. Dias de overflow não entram. | ✓ |
| Todo o grid visível | Conta tudo que aparece no calendário, inclusive overflow de outros meses. Mais simples. | |

**User's choice:** Só o mês corrente
**Notes:** Mais preciso — o título da página já diz o mês; overflow seria confuso.

---

### Como calcular as contagens do mês corrente?

| Option | Description | Selected |
|--------|-------------|----------|
| No controller | Adicionar @summary no HomeController#index. View fica limpa. | ✓ |
| Na view | Calcular inline no index.html.erb. Evita mudar o controller, mas a view fica com lógica. | |

**User's choice:** No controller
**Notes:** Mantém a view limpa conforme padrão estabelecido no projeto.

---

## Status exibidos

### A faixa deve mostrar o status "revisado"?

| Option | Description | Selected |
|--------|-------------|----------|
| Não, apenas os 3 do requisito | Total, aprovadas, pendentes, pediu alteração. "Revisado" é transitório. | ✓ |
| Sim, incluir revisado | 4 statuses: aprovadas, pendentes, pediu alteração, revisadas. | |

**User's choice:** Não — apenas os 3 do requisito
**Notes:** Conforme CAL2-01. "Revisado" é estado intermediário do admin, não relevante para o cliente.

---

### Como artes com status "revisado" devem aparecer na contagem?

| Option | Description | Selected |
|--------|-------------|----------|
| Dentro de Pendentes | Revisado = aguarda aprovação do cliente. pending + revised = contador Pendentes. | ✓ |
| Ignorar revisado | Artes revisadas não entram em nenhum contador. | |

**User's choice:** Dentro de Pendentes
**Notes:** Revisado significa que o admin fez as alterações e o cliente precisa re-aprovar — logicamente é pendente.

---

## Layout visual da faixa

### Como a faixa de resumo deve aparecer visualmente?

| Option | Description | Selected |
|--------|-------------|----------|
| Chips coloridos inline | 4 chips com cor de status, separador ·. Ex: 12 total · 5 aprovadas · 4 pendentes · 3 pediu alteração | ✓ |
| Cards com número grande | 4 cards lado a lado com número grande e label embaixo. | |

**User's choice:** Chips coloridos inline
**Notes:** Mais compacto, mantém o estilo do calendário sem adicionar peso visual.

---

### Onde exatamente a faixa deve aparecer?

| Option | Description | Selected |
|--------|-------------|----------|
| Entre navegação e grade | Logo abaixo do header "< Junho 2026 >", acima da grade. | ✓ |
| Inline no header de navegação | Ao lado ou abaixo do título do mês, na mesma linha. | |

**User's choice:** Entre navegação e grade
**Notes:** Fluxo de leitura natural: mês → resumo → calendário.

---

### Quando não há artes no mês, o que a faixa deve exibir?

| Option | Description | Selected |
|--------|-------------|----------|
| Faixa oculta | Se total = 0, a faixa não aparece. | ✓ |
| Exibir com zeros | Mostrar sempre, mesmo com 0 em todos. | |

**User's choice:** Faixa oculta
**Notes:** Evita mostrar "0 aprovadas · 0 pendentes" desnecessários.

---

## Texto mobile

| Option | Description | Selected |
|--------|-------------|----------|
| flex-wrap | Faixa usa flex-wrap: wrap — chips que não cabem em uma linha vão para a próxima. Labels íntegros. | ✓ |
| Abreviar | Mudar label para 'Alteração' nos chips (consistente com badge compact=true). | |
| Ignorar | Não tratar mobile especificamente — faixa pode transbordar. | |

**User's choice:** flex-wrap (Recomendado)
**Notes:** Labels intactos em todas as telas. Simples de implementar.

---

## Atualização após aprovação (SC4)

| Option | Description | Selected |
|--------|-------------|----------|
| Reload via redirect | Controller recalcula @summary a cada request; após aprovação o redirect existente atualiza a faixa automaticamente. | ✓ |
| Turbo Stream | Atualizar só a faixa via Turbo Stream após aprovação — sem reload completo. | |

**User's choice:** Reload via redirect (Recomendado)
**Notes:** SSR-first consistente com o padrão da aplicação. SC4 satisfeito automaticamente.

---

## Partial vs inline

| Option | Description | Selected |
|--------|-------------|----------|
| Inline no index | Faixa (~10 linhas) inline no index.html.erb — sem arquivo extra. | ✓ |
| Partial _summary_strip.html.erb | Extrair para partial em app/views/client/home/_summary_strip.html.erb. | |

**User's choice:** Inline no index (Recomendado)
**Notes:** Faixa simples; inline mantém tudo legível num lugar só.

---

## Claude's Discretion

- Formatação exata dos chips (padding, gap, border-radius) — seguir estilo do `_arte_status_badge.html.erb`

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
