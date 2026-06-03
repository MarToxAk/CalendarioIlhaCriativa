# Phase 8: Approval Bug Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-02
**Phase:** 8-Approval Bug Fix
**Areas discussed:** Estratégia de fix, Feedback pós-aprovação, Cobertura de teste

---

## Estratégia de fix

| Option | Description | Selected |
|--------|-------------|----------|
| View: scope na view | Adicionar `scope: :approval_response` nos 2 form_with da view. 2 linhas alteradas. Controller já está correto. | ✓ |
| Controller: adaptar leitura de params | Mudar o controller para ler `params[:decision]` sem require(:approval_response). Mais invasivo, rompe padrão Rails. | |

**User's choice:** View: scope na view (Recomendado)
**Notes:** Fix mínimo, cirúrgico. Controller e testes existentes já estão corretos.

---

## Feedback pós-aprovação

| Option | Description | Selected |
|--------|-------------|----------|
| Manter redirect existente | Full reload de client_arte_path mostra badge atualizado + flash de sucesso. Simples. | ✓ |
| Turbo Stream: atualizar badge inline | Controller retorna Turbo Stream atualizando só o badge. Melhor UX, mas adiciona complexidade. | |

**User's choice:** Manter redirect existente (Recomendado)
**Notes:** O comportamento pós-aprovação já está implementado corretamente no controller; basta fazer o bug fix na view.

---

## Cobertura de teste

| Option | Description | Selected |
|--------|-------------|----------|
| Confiar nos testes existentes | 6 casos já cobrem APRO-01, APRO-02, duplo-envio, IDOR e auth com formato correto. | ✓ |
| Adicionar teste de regressão da view | System/integration test simulando browser enviando o form. | |

**User's choice:** Confiar nos testes existentes (Recomendado)
**Notes:** O fix está na view; os testes de controller exercitam o controller diretamente com params corretos.

---

## Claude's Discretion

- Verificar se há outros locais no código que usam `form_with` para `approval_response` sem scope

## Deferred Ideas

None — discussão ficou dentro do escopo da fase.
