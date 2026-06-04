# Phase 13: Página Aprovações - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 13-Página Aprovações
**Areas discussed:** Status no filtro, Layout da lista

---

## Status no filtro

| Option | Description | Selected |
|--------|-------------|----------|
| Decision da resposta | Filtra pelo `decision` de ApprovalResponse: Aprovado / Pediu Alteração (2 opções) | ✓ |
| Status atual da arte | Filtra por Arte.status: Pendente / Aprovado / Pediu Alteração / Revisado (4 opções) | |
| Ambos (dois dropdowns) | Um dropdown para cada | |

**User's choice:** Decision da resposta (Aprovado / Pediu Alteração)
**Notes:** Escolha recomendada aceita — mais direto com o que approval_responses.decision já tem.

---

## Layout da lista

### Organização visual

| Option | Description | Selected |
|--------|-------------|----------|
| Lista plana cronológica | Uma linha por resposta, ordenada da mais recente para a mais antiga | ✓ |
| Agrupada por cliente | Subtítulo por cliente, como o dashboard atual | |
| Agrupada por arte | Subtítulo por arte, mostrando histórico de cada arte | |

**User's choice:** Lista plana cronológica
**Notes:** APRO-04 pede "ordenada pela mais recente" — lista plana é o match natural.

### Itens por página

| Option | Description | Selected |
|--------|-------------|----------|
| 25 por página | Padrão equilibrado para audit trail | ✓ |
| 50 por página | Mais itens visíveis de uma vez | |

**User's choice:** 25 por página
**Notes:** pagy já está no Gemfile — sem nova dependência.

---

## Claude's Discretion

- Nome do controller/rota: `Admin::ApprovalsController` com `resources :approvals, only: [:index]`
- Padrão Turbo Frame para filtros: replicar o padrão já estabelecido no dashboard (Phase 6)
- Visual de tabela: padrão Phase 11 (thead uppercase, hover:bg-slate-50)
- Coluna "status" exibe `decision` da response (não status da arte)

## Deferred Ideas

Nenhuma — discussão manteve-se dentro do escopo da fase.
