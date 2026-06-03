---
phase: 08-approval-bug-fix
verified: 2026-06-02T23:10:00-03:00
status: human_needed
score: 4/6 must-haves verified (2 requerem verificação visual humana)
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Verificação visual — botão Aprovar no portal do cliente"
    expected: "Clicar em 'Aprovar' na página de detalhe da arte recarrega a página com flash 'Arte aprovada!' e o badge de status muda para 'Aprovado' (verde). NÃO deve exibir 'Resposta inválida.'"
    why_human: "Comportamento de renderização de badge e flash na resposta HTTP real não é verificável via grep; depende de renderização em browser com sessão autenticada"
  - test: "Verificação visual — botão Pedir Alteração (com e sem comentário)"
    expected: "Clicar em 'Pedir Alteração', digitar comentário e enviar exibe flash 'Pedido de alteração enviado.' e badge muda para 'Revisão solicitada'. O mesmo deve acontecer sem digitar comentário. NÃO deve exibir 'Resposta inválida.'"
    why_human: "Mesmo motivo: renderização de flash e badge requer execução real no browser"
  - test: "(SC3) Badge no calendário do cliente reflete estado atualizado após aprovação"
    expected: "Após aprovar uma arte, acessar o calendário mensal do cliente e confirmar que o badge/indicador visual da arte aprovada exibe 'Aprovado', não 'Pendente' ou estado anterior"
    why_human: "Renderização do calendário é visual; o estado correto é gravado no banco (verificado pelos testes de controller), mas a exibição no calendário exige inspeção em browser"
  - test: "(SC4) Painel admin de feedback exibe resposta registrada"
    expected: "Após o cliente registrar aprovação ou pedido de alteração, acessar o painel admin de feedback e confirmar que a nova resposta aparece listada com decisão e comentário (quando aplicável)"
    why_human: "Exibição no painel admin é visual; a gravação no banco é verificada pelos testes (ApprovalResponse.count +1), mas a listagem no painel exige inspeção em browser"
---

# Phase 8: Approval Bug Fix — Verification Report

**Phase Goal:** Corrigir o bug "Resposta inválida" nos botões Aprovar e Pedir Alteração do portal do cliente. Os dois form_with omitiam scope: :approval_response, fazendo os campos chegarem como params[:decision] em vez de params[:approval_response][:decision]. Adicionando scope: :approval_response nos dois formulários, o fluxo completo (APRO-01, APRO-02) funciona.
**Verified:** 2026-06-02T23:10:00-03:00
**Status:** human_needed
**Re-verification:** No — verificação inicial

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                      | Status       | Evidência                                                                                                              |
|----|-------------------------------------------------------------------------------------------------------------|--------------|------------------------------------------------------------------------------------------------------------------------|
| 1  | Cliente clica em "Aprovar" e a arte é aprovada sem exibir "Resposta inválida"                              | ? HUMAN      | Fix presente na view (linha 110); testes T1 e T3 passam; renderização visual requer browser                           |
| 2  | Cliente clica em "Pedir Alteração" (com ou sem comentário) e a resposta é gravada sem exibir "Resposta inválida" | ? HUMAN | Fix presente na view (linha 123); testes T2, T3 passam; renderização visual requer browser                            |
| 3  | Após registrar resposta, o badge de status da arte reflete o novo estado na página de detalhe              | ? HUMAN      | Controller redireciona para client_arte_path após gravação com sucesso; badge é renderizado na view; requer browser    |
| 4  | Os 6 testes existentes em responses_controller_test.rb continuam passando após o fix                       | ✓ VERIFIED   | `rails test test/controllers/client/responses_controller_test.rb` → 6 runs, 37 assertions, 0 failures, 0 errors       |
| 5  | Após aprovar, o badge da arte no calendário do cliente muda para o estado aprovado (SC3)                   | ? HUMAN      | Arte.status é gravado corretamente (verificado em T1: `@arte_a.reload.approved?`); exibição no calendário requer browser |
| 6  | Após registrar resposta, o painel admin de feedback exibe a nova resposta registrada (SC4)                 | ? HUMAN      | ApprovalResponse é gravado no banco (verificado em T1/T2 com assert_difference); exibição no painel requer browser     |

**Score (automatizável):** 2/2 truths verificáveis via grep/teste — VERIFIED. 4 truths requerem verificação visual humana.

---

### Required Artifacts

| Artifact                                    | Esperado                                       | Status     | Detalhes                                                                                        |
|---------------------------------------------|------------------------------------------------|------------|-------------------------------------------------------------------------------------------------|
| `app/views/client/artes/show.html.erb`      | Formulários com `scope: :approval_response`    | ✓ VERIFIED | 2 ocorrências confirmadas via grep (linhas 110 e 123); único arquivo a conter o path            |

**Verificação de existência:**
- Arquivo existe: sim
- Conteúdo substantivo: sim (169 linhas; view completa com seção de mídia, metadados, botões de aprovação, histórico)
- Wired: sim (servido pela rota `client_arte_path`; formulários POST para `client_arte_responses_path`)

---

### Key Link Verification

| From                                        | To                                                     | Via                                           | Status     | Detalhes                                                                                                                                 |
|---------------------------------------------|--------------------------------------------------------|-----------------------------------------------|------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `app/views/client/artes/show.html.erb`      | `app/controllers/client/responses_controller.rb`       | `form POST com params[approval_response][decision]` | ✓ WIRED | Linha 110: `scope: :approval_response` presente; linha 123: `scope: :approval_response` presente. Controller usa `params.dig(:approval_response, :decision)` — wrapper agora existe |

**Detalhe do fix:**

Antes do fix (causa do bug):
```erb
form_with url: client_arte_responses_path(...), method: :post, class: "inline"
```
`f.hidden_field :decision` gerava `params[:decision]` → `params.dig(:approval_response, :decision)` retornava `nil` → guard disparava "Resposta inválida"

Após o fix (correto):
```erb
form_with url: client_arte_responses_path(...), method: :post, scope: :approval_response, class: "inline"
```
`f.hidden_field :decision` gera `params[:approval_response][:decision]` → guard passa → resposta gravada

---

### Data-Flow Trace (Level 4)

| Artifact              | Variável de dado          | Fonte                                           | Produz dado real | Status      |
|-----------------------|---------------------------|-------------------------------------------------|------------------|-------------|
| `show.html.erb`       | `@arte.status` (badge)    | `Arte.status` (enum) — gravado pelo controller  | Sim              | ✓ FLOWING   |
| `responses_controller`| `params[:approval_response][:decision]` | `form_with scope: :approval_response` na view | Sim | ✓ FLOWING   |

---

### Behavioral Spot-Checks

| Comportamento                                                  | Comando                                                                              | Resultado                                       | Status   |
|----------------------------------------------------------------|--------------------------------------------------------------------------------------|-------------------------------------------------|----------|
| 6 testes de controller passam sem falhas                       | `rails test test/controllers/client/responses_controller_test.rb`                    | 6 runs, 37 assertions, 0 failures, 0 errors      | ✓ PASS   |
| View contém exatamente 2 ocorrências de `scope: :approval_response` | `grep -c "scope: :approval_response" app/views/client/artes/show.html.erb`     | 2                                               | ✓ PASS   |
| Apenas os 2 formulários esperados usam `client_arte_responses_path` | `grep -rn "client_arte_responses_path" app/views/`                            | 2 ocorrências — ambas em `client/artes/show.html.erb` | ✓ PASS |
| Controller não foi modificado                                  | `git diff app/controllers/client/responses_controller.rb`                            | Sem saída (zero alterações)                     | ✓ PASS   |
| Fix commitado em commit dedicado                               | `git show c91301a --stat`                                                            | `1 file changed, 2 insertions(+), 2 deletions(-)` em `show.html.erb` | ✓ PASS |

---

### Probe Execution

Não aplicável. Esta fase não declara probes em `.planning/phases/08-approval-bug-fix/08-01-PLAN.md` e não é uma fase de migração/tooling.

---

### Requirements Coverage

| Requirement | Plano declarante | Descrição                                                                             | Status       | Evidência                                                                                         |
|-------------|------------------|---------------------------------------------------------------------------------------|--------------|---------------------------------------------------------------------------------------------------|
| APRO-01     | 08-01-PLAN.md    | Cliente consegue aprovar uma arte clicando em "Aprovar" sem receber erro "Resposta inválida" | ? HUMAN | Fix na view verificado (linha 110); Test 1 passa; renderização final requer browser                |
| APRO-02     | 08-01-PLAN.md    | Cliente consegue pedir alteração (com ou sem comentário) sem receber erro "Resposta inválida" | ? HUMAN | Fix na view verificado (linha 123); Tests 2 e 3 passam; renderização final requer browser          |

**Requisitos órfãos (mapeados para esta fase no REQUIREMENTS.md mas ausentes do PLAN):** Nenhum. REQUIREMENTS.md lista apenas APRO-01 e APRO-02 para a Phase 8. Ambos estão no frontmatter do plano.

**Outros requisitos do v1.2 (não desta fase):** CAL2-01 está mapeado para Phase 9 — não é responsabilidade desta fase.

---

### Anti-Patterns Found

| Arquivo                                     | Linha | Padrão     | Severidade | Impacto                                                                 |
|---------------------------------------------|-------|------------|------------|-------------------------------------------------------------------------|
| `app/views/client/artes/show.html.erb`      | 126   | `placeholder:` | ℹ Info | Atributo HTML legítimo do `f.text_area` (texto orientativo para o campo de comentário). Não é stub — não flui para renderização de dados. |

Nenhum marcador `TBD`, `FIXME`, `XXX` encontrado no arquivo modificado.

---

### Human Verification Required

#### 1. Botão Aprovar — fluxo completo

**Test:** Acessar o portal do cliente (URL com token), abrir uma arte com status "pending", clicar em "Aprovar"
**Expected:** Página recarrega com flash "Arte aprovada!" e o badge de status muda para "Aprovado" (verde). NÃO deve exibir "Resposta inválida."
**Why human:** Renderização de flash e badge na resposta HTTP real não é verificável via grep; depende de execução em browser com sessão autenticada

#### 2. Botão Pedir Alteração — com comentário

**Test:** Acessar a página de detalhe de outra arte "pending", clicar em "Pedir Alteração", digitar um comentário e enviar
**Expected:** Página recarrega com flash "Pedido de alteração enviado." e badge muda para "Revisão solicitada". NÃO deve exibir "Resposta inválida."
**Why human:** Mesmo motivo do teste 1

#### 3. Botão Pedir Alteração — sem comentário

**Test:** Acessar a página de detalhe de outra arte "pending", clicar em "Pedir Alteração" sem digitar comentário e enviar
**Expected:** Resposta gravada com flash "Pedido de alteração enviado.". NÃO deve exibir "Resposta inválida."
**Why human:** Mesmo motivo do teste 1

#### 4. (SC3) Badge no calendário reflete estado atualizado

**Test:** Após aprovar a arte no teste 1, acessar o calendário mensal do cliente e confirmar que o badge/indicador da arte aprovada exibe "Aprovado"
**Expected:** Badge mostra "Aprovado", não "Pendente" ou estado anterior
**Why human:** Renderização do calendário é visual; o estado é gravado corretamente no banco (verificado pelos testes de controller), mas a exibição na view do calendário exige inspeção em browser

#### 5. (SC4) Painel admin de feedback exibe resposta registrada

**Test:** Após o cliente registrar aprovação ou pedido de alteração, acessar o painel admin de feedback e confirmar que a nova resposta aparece listada
**Expected:** Resposta visível com decisão (Aprovado / Pediu Alteração) e comentário (quando aplicável)
**Why human:** A gravação no banco é verificada pelos testes (assert_difference "ApprovalResponse.count", 1), mas a listagem no painel admin exige inspeção em browser

---

### Gaps Summary

Nenhum gap bloqueante encontrado. O fix técnico está correto e completo:

- `scope: :approval_response` adicionado nos dois `form_with` (linhas 110 e 123 de `app/views/client/artes/show.html.erb`)
- Apenas o arquivo declarado no PLAN foi modificado
- Controller, model e testes permanecem inalterados conforme especificado
- Todos os 6 testes passam (6 runs, 37 assertions, 0 failures, 0 errors)
- O link crítico view → controller está corretamente fiado

As 4 verificações marcadas como `human_needed` são de natureza visual (renderização de badge, flash, exibição em calendário e painel admin) — não indicam problema no código, mas exigem confirmação humana para o sign-off final da fase.

---

_Verified: 2026-06-02T23:10:00-03:00_
_Verifier: Claude (gsd-verifier)_
