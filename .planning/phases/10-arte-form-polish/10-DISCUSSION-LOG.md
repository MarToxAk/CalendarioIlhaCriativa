# Phase 10: Arte Form Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 10-arte-form-polish
**Areas discussed:** Largura do card, Radio buttons de mídia, File input

---

## Largura do card

| Option | Description | Selected |
|--------|-------------|----------|
| max-w-lg (igual clients) | 512px — consistente com o rest do painel | |
| max-w-2xl (maior) | 672px — mais respiro para o form longo | |
| Você decide | Claude escolhe o que parecer mais adequado | ✓ |

**User's choice:** Você decide (Claude escolheu max-w-2xl)
**Notes:** Form de artes tem ~10 campos vs ~3 nos clients. Claude decidiu por max-w-2xl para dar respiro adequado, aceitando quebrar paridade de largura com o card de clients.

---

## Radio buttons de mídia

### Pergunta 1: Estilo geral

| Option | Description | Selected |
|--------|-------------|----------|
| Minimalista (labels legíveis) | Manter flex gap-4, adicionar cursor-pointer e font-medium | |
| Pill/box interativo | Cada opção vira botão pill com border e estado ativo verde | ✓ |

**User's choice:** Pill/box interativo

---

### Pergunta 2: Como atualizar estado ativo

| Option | Description | Selected |
|--------|-------------|----------|
| CSS :has() (sem JS extra) | `label:has(input:checked)` — zero JS, browsers modernos | |
| Stimulus controller (mais compatível) | Estender media-type-toggle com targets de label | ✓ |

**User's choice:** Stimulus controller

---

### Pergunta 3: Visibilidade do input nativo

| Option | Description | Selected |
|--------|-------------|----------|
| Esconder o input (sr-only) | Acessível via teclado, invisível. Pill inteiro é área de clique | ✓ |
| Manter visível | Radio nativo visível dentro do pill | |

**User's choice:** Esconder o input (sr-only)

---

## File input

| Option | Description | Selected |
|--------|-------------|----------|
| Tailwind file: pseudo | Classes `file:` direto no input nativo. Sem JS extra | ✓ |
| Label estilizado + input hidden | Controle total do visual, mas requer JS para nome do arquivo | |
| Você decide | Claude escolhe | |

**User's choice:** Tailwind file: pseudo (Recomendado)
**Notes:** Solução mais simples — sem complexidade extra. O pseudo-elemento `file:` do Tailwind v4 dá controle suficiente sobre o botão nativo.

---

## Claude's Discretion

- **Largura do card:** Claude escolheu `max-w-2xl` (usuário deixou a critério). Razão: form com ~10 campos precisa de mais respiro que os ~3 campos do form de clients.

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
