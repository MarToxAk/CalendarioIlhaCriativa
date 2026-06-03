# Phase 8: Approval Bug Fix - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Corrigir o bug "Resposta inválida" nos botões Aprovar e Pedir Alteração do portal do cliente. O cliente clica em um dos botões e a resposta é gravada corretamente no banco sem exibir mensagem de erro. O fix está inteiramente na view (`client/artes/show.html.erb`) — o controller e os testes existentes já estão corretos.

Requirements: APRO-01, APRO-02.

**Fora do escopo desta fase:** Faixa de resumo do calendário (Phase 9), notificações, Turbo Stream, mudanças no painel admin.

</domain>

<decisions>
## Implementation Decisions

### Estratégia de fix

- **D-01:** O bug está nos dois `form_with url:` em `app/views/client/artes/show.html.erb`. Sem `scope: :approval_response`, os campos são enviados como `params[:decision]` em vez de `params[:approval_response][:decision]`. O controller faz `params.dig(:approval_response, :decision)` → `nil` → "Resposta inválida".
- **D-02:** Fix: adicionar `scope: :approval_response` nos dois `form_with` da view. Alteração mínima de 2 linhas. O controller (`Client::ResponsesController`) e os testes existentes já estão corretos e não precisam ser alterados.

### Feedback pós-aprovação

- **D-03:** Manter o comportamento de redirect existente: após salvar, o controller faz `redirect_to client_arte_path` com flash de sucesso. A página de detalhe da arte recarrega exibindo o badge de status atualizado. Nenhuma lógica de Turbo Stream necessária.

### Cobertura de teste

- **D-04:** Confiar nos testes de controller existentes (`test/controllers/client/responses_controller_test.rb`, 6 casos). Eles já cobrem APRO-01, APRO-02, duplo-envio, IDOR e auth com o formato correto de params. Nenhum teste novo necessário para este fix.

### Claude's Discretion

- Verificar se há outros locais no código que usam `form_with` para `approval_response` sem scope (improvável, mas confirmar durante implementação)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### View com o bug

- `app/views/client/artes/show.html.erb` — **ARQUIVO CENTRAL DO FIX**: contém os dois `form_with url:` sem `scope:` (linhas ~130-165 na seção "botões de aprovação"). Adicionar `scope: :approval_response` em ambos.

### Controller (já correto — não alterar)

- `app/controllers/client/responses_controller.rb` — `create` action: guarda `params.dig(:approval_response, :decision)`, chama `response_params` com `params.require(:approval_response).permit(:decision, :comment)`. Correto como está.

### Testes (já cobrem os cenários — não alterar)

- `test/controllers/client/responses_controller_test.rb` — 6 casos cobrindo APRO-01, APRO-02, duplo-envio, IDOR, sem auth. Todos usam `params: { approval_response: { decision: ... } }` — confirmar que continuam passando após o fix.

### Model

- `app/models/approval_response.rb` — enum `decision` (`approved: 0`, `change_requested: 1`), `validates :decision, presence: true`, `after_create :sync_arte_status` (atualiza status da arte). Correto como está.

### Requisitos

- `.planning/REQUIREMENTS.md` — APRO-01, APRO-02 mapeados para Phase 8

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `client_arte_responses_path(token:, arte_id:)` — helper de rota já usado nos dois `form_with`; mantido após o fix
- `approval` Stimulus controller (`app/javascript/controllers/approval_controller.js`) — apenas controla visibilidade do formulário de comentário (toggle/hide); não interfere com a submissão do form

### Established Patterns

- `form_with url:, scope:` — padrão Rails para enviar params com wrapper sem model object; solução canônica para este caso de uso
- Flash messages: `redirect_to ..., notice:` / `alert:` — padrão existente em todo o app; o controller já usa corretamente
- `params.require(:model).permit(...)` — padrão Strong Parameters do Rails; já aplicado no controller

### Integration Points

- `app/views/client/artes/show.html.erb` seção "botões de aprovação": dois `form_with` sem scope → adicionar `scope: :approval_response` em cada um
- Formulário "Aprovar" (`form_with ... class: "inline"`): `f.hidden_field :decision, value: "approved"` — scope fará gerar `approval_response[decision]`
- Formulário "Pedir Alteração" (inline, oculto por default): `f.hidden_field :decision, value: "change_requested"` + `f.text_area :comment` — scope fará gerar `approval_response[decision]` e `approval_response[comment]`

</code_context>

<specifics>
## Specific Ideas

- Fix de 2 linhas na view; zero mudanças no controller, model ou testes
- Após o fix, rodar `rails test test/controllers/client/responses_controller_test.rb` para confirmar todos os 6 casos passam

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 8-Approval Bug Fix*
*Context gathered: 2026-06-02*
