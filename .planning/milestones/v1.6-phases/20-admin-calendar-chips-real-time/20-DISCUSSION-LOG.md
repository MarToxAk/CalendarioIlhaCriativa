# Phase 20: Admin Calendar Chips Real-time - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-09
**Phase:** 20-admin-calendar-chips-real-time
**Areas discussed:** Indicador visual de status, Estilo/cobertura do indicador, Transições, Granularidade do replace + overflow

---

## Indicador visual de status no chip

| Option | Description | Selected |
|--------|-------------|----------|
| Anel/borda colorido por status | Fundo do chip continua com a cor do cliente; ganha anel fino colorido por status reutilizando o STATUS_MAP. | ✓ |
| Ponto de status no canto | Mantém o chip e adiciona um dot colorido no canto; pode ficar apertado no chip pequeno. | |
| Só atualizar data-arte_status | Nenhuma mudança visível na grade; apenas o data attribute atualiza para tooltip/modal. | |

**User's choice:** Anel/borda colorido por status (Recommended)
**Notes:** Decisão central da fase. O chip admin hoje é colorido por cliente e o status só existe em `data-arte_status` (tooltip), então sem o anel a atualização ao vivo seria imperceptível sem hover.

---

## Estilo / cobertura do anel

| Option | Description | Selected |
|--------|-------------|----------|
| Só approved / change_requested / revised | pending = sem anel (estado neutro/inicial); grade fica limpa, anel surgindo é o sinal de mudança. | ✓ |
| Todos os 4 status | Inclui anel âmbar para pending; mais explícito, mas grade nasce cheia de anéis. | |

**User's choice:** Só approved / change_requested / revised (Recommended)
**Notes:** Cores do anel saem do `STATUS_MAP` (campo `color`): approved #14A958, change_requested #EE3537, revised #475569.

---

## Transições que disparam o update

| Option | Description | Selected |
|--------|-------------|----------|
| Todas as três | approved, change_requested e revised; ambos os broadcasts existentes recebem um turbo-stream a mais. | ✓ |
| Só mudanças do cliente | Apenas approved e change_requested (via ApprovalResponse); revised não atualizaria ao vivo. | |

**User's choice:** Todas as três (Recommended)
**Notes:** `ApprovalResponse#broadcasts_to_admin` cobre approved + change_requested; `Arte#broadcasts_revised_to_all` cobre revised. Ambos já fazem broadcast ao admin — custo mínimo.

---

## Granularidade do replace + overflow

| Option | Description | Selected |
|--------|-------------|----------|
| Replace cirúrgico do chip | Extrair chip para partial com dom_id; replace só do chip. Overflow (4ª+) falha silenciosamente. | ✓ |
| Replace da célula do dia inteira | Re-renderiza a célula toda (robusto p/ overflow e recontagem), mas mais pesado e acoplado. | |

**User's choice:** Replace cirúrgico do chip (Recommended)
**Notes:** Simétrico com Phase 19 D-05. Overflow e mês diferente → falha silenciosa, mesma tolerância da Phase 19 D-07.

---

## Claude's Discretion

- Espessura/estilo exato do anel (ring-2 vs border/outline) adequado ao chip pequeno
- Como expor as cores de status no Ruby/ERB (helper espelhando o STATUS_MAP)
- Locals exatos da partial e reconstrução de `client_color` para o broadcast
- Ordem do turbo-stream do chip dentro de cada array de streams

## Deferred Ideas

- Recontagem do "+N" de overflow em tempo real — fora de escopo
- Atualização ao vivo quando uma arte NOVA é criada/agendada — fora do v1.5
- Indicador de presença / "cliente está visualizando" — desnecessário para o volume atual
