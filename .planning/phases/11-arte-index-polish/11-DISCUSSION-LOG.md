# Phase 11: Arte Index Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 11-arte-index-polish
**Areas discussed:** Botão "Ver", Empty state, Mobile

---

## Botão "Ver" nas rows

| Option | Description | Selected |
|--------|-------------|----------|
| Botão outline pequeno | h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 | ✓ |
| Link de texto simples | text-sm text-[#0F7949] hover:underline — mínimo | |
| Row inteira clicável | Remover coluna "Ver" e tornar tr em link | |

**User's choice:** Botão outline pequeno
**Notes:** Discreto, não compete visualmente com "Nova Arte"

---

## Empty state

| Option | Description | Selected |
|--------|-------------|----------|
| Replicar o clients | SVG + título + texto + botão "Cadastrar primeira arte" | ✓ |
| Mensagem simples | Só texto "Nenhuma arte cadastrada" | |
| Sem empty state | Tabela vazia | |

**User's choice:** Replicar o clients
**Notes:** Consistência visual com o resto do admin

---

## Mobile

| Option | Description | Selected |
|--------|-------------|----------|
| Cards mobile como o clients | hidden sm:block na tabela + cards block sm:hidden | ✓ |
| Só desktop (tabela responsiva) | overflow-x-auto, mais simples | |

**User's choice:** Cards mobile como o clients
**Notes:** Padrão já estabelecido no clients

---

## Claude's Discretion

- Classes exatas dos th/td (py-3 px-4, etc.) — replicar diretamente do clients canonical.
- Campos exibidos nos cards mobile — cliente, status, data.

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
