# Phase 12: Arte Show & Dashboard Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 12-arte-show-dashboard-fix
**Areas discussed:** Layout do show, Marcar como Revisada, Ver no dashboard

---

## Layout do show

| Option | Description | Selected |
|--------|-------------|----------|
| Separar Voltar como text link | Padrão igual ao clients/show: '← Artes' como text link discreto no topo, e Editar + Excluir + Marcar Revisada como action buttons. Mantém consistência com o restante do painel. | ✓ |
| Manter inline | Todos os 4 botões no mesmo flex gap-2 como estão. Mais simples, menos consistente com clients/show. | |

**User's choice:** Separar Voltar como text link (Recomendado)
**Notes:** Texto do link: `← Artes` apontando para `admin_artes_path`.

---

## Marcar como Revisada

| Option | Description | Selected |
|--------|-------------|----------|
| Verde sólido | bg-[#0F7949] text-white — mesmo padrão do botão primário/submit. Sinaliza ação positiva principal. | ✓ |
| Outline neutro | Igual ao Editar — border border-gray-200. Mais discreto, trata Editar e Marcar Revisada como equivalentes. | |

**User's choice:** Verde sólido (Recomendado)
**Notes:** Faz sentido porque é o único CTA real quando a arte está em 'pediu alteração'.

---

## Ver no dashboard

| Option | Description | Selected |
|--------|-------------|----------|
| Mesmo estilo do index | h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors — consistência total entre index e dashboard. | ✓ |
| Estilo diferente | Criar uma variação para o dashboard (ex: mais compacto ou com cor diferente). | |

**User's choice:** Sim, mesmo estilo (Recomendado)
**Notes:** Carry-forward direto da D-02 da Fase 11.

---

## Claude's Discretion

- `aria: { label: "Voltar para lista de artes" }` no text link — paridade com clients/show (que tem aria-label).
- `h-9 px-4` (vs `px-3` do Editar) para o botão "Marcar como Revisada" — leve destaque visual ao CTA principal.

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
