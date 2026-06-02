---
phase: 07-art-upload-client-scoping-fix
verified: 2026-06-02T17:30:00Z
status: gaps_found
score: 3/6 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Admin não consegue acessar, editar ou excluir arte de outro cliente mesmo manipulando a URL (SC3)"
    status: failed
    reason: "set_arte usa Arte.includes(:approval_responses).find(params[:id]) sem nenhum filtro por client_id ou verificação de pertencimento. Qualquer arte pode ser acessada por URL direta. A decisão D-07 do CONTEXT.md descarta a proteção cross-client como 'sistema single-admin', mas o ROADMAP.md define SC3 explicitamente como critério de sucesso desta fase — a implementação não satisfaz o critério do contrato."
    artifacts:
      - path: "app/controllers/admin/artes_controller.rb"
        issue: "set_arte (linha 58-61) faz Arte.find(params[:id]) sem where(client: @client) ou verificação de pertencimento equivalente"
    missing:
      - "Adicionar verificação em set_arte: após Arte.find(params[:id]), confirmar que @arte.client == @client (quando @client presente) ou usar Arte.where(client_id: params[:client_id]).find(params[:id])"
  - truth: "Artes listadas no painel do admin são sempre escopadas ao cliente selecionado, sem vazamento cross-client (SC4)"
    status: failed
    reason: "O index action carrega @artes = Arte.includes(:client).order(scheduled_on: :desc) sem qualquer filtro por cliente. A view index.html.erb exibe artes de todos os clientes em uma única tabela sem escopamento. O comentário '# Filtering logic can be added here' na linha 12 do controller confirma que o escopamento está por ser implementado."
    artifacts:
      - path: "app/controllers/admin/artes_controller.rb"
        issue: "index action (linhas 7-13) carrega todas as artes sem filtro por cliente; comentário inline '# Filtering logic can be added here' é marcador de trabalho pendente"
      - path: "app/views/admin/artes/index.html.erb"
        issue: "Exibe todas @artes sem distinção ou filtro de cliente — a coluna 'Cliente' mostra o nome mas não há escopamento de dados"
    missing:
      - "Implementar filtragem por cliente no index action quando params[:client_id] presente, ou adicionar filtro de URL na view"
      - "Remover ou referenciar o comentário '# Filtering logic can be added here' com issue tracker antes de fechar a fase"
  - truth: "Comentário de dívida técnica sem referência rastreável em arquivo modificado pela fase"
    status: failed
    reason: "app/controllers/admin/artes_controller.rb linha 12 contém '# Filtering logic can be added here' — marcador de trabalho incompleto sem referência a issue ou PR. Pela gate de marcadores de dívida: qualquer comentário indicando trabalho pendente sem referência formal é BLOCKER."
    artifacts:
      - path: "app/controllers/admin/artes_controller.rb"
        issue: "Linha 12: '# Filtering logic can be added here' — marcador de dívida não rastreável"
    missing:
      - "Implementar a filtragem (resolve SC4) OU referenciar issue formal (#N) no comentário"
human_verification:
  - test: "Upload de arquivo ao criar arte"
    expected: "Admin navega para /admin/artes/new, preenche o form, seleciona um arquivo via campo 'Arquivo', submete — arte é criada e o arquivo fica acessível no portal do cliente (imagem exibida ou vídeo com player)"
    why_human: "ActiveStorage.attached? e rails_blob_path funcionam somente com servidor rodando e arquivo real armazenado; não pode ser verificado por grep"
  - test: "Re-exibição de erros de :base após falha de validação"
    expected: "Submeter form sem selecionar mídia (nem upload nem link) exibe a mensagem 'Precisa de arquivo ou link externo' no topo do form em caixa vermelha (bg-red-50)"
    why_human: "Comportamento de re-renderização após falha de validação requer request HTTP real ao servidor"
  - test: "Selector de cliente exibido em /admin/artes/new sem client_id"
    expected: "Navegar diretamente para /admin/artes/new (sem ?client_id=X) exibe um <select> de clientes com prompt 'Selecione o cliente'. Selecionar um cliente e submeter cria a arte com client_id correto."
    why_human: "Comportamento condicional depende do valor de arte.client_id em runtime — requer request real"
  - test: "hidden_field mantido ao criar arte via página do cliente"
    expected: "Navegar via /admin/clients/:id → botão 'Nova Arte' (que vai para /admin/artes/new?client_id=:id) exibe hidden_field com client_id pré-preenchido — o selector NÃO é exibido"
    why_human: "Comportamento condicional depende do valor de arte.client_id em runtime"
---

# Phase 07: Art Upload & Client Scoping Fix — Verification Report

**Phase Goal:** Corrigir bug de upload de arte onde @client nil impedia criação de artes. Adicionar @client ao set_arte e corrigir o form com selector condicional de cliente e exibição de erros de :base.
**ROADMAP Goal:** Upload de arquivos de artes funciona via ActiveStorage e o client_id é sempre derivado do contexto correto, com proteção contra acesso cross-client.
**Verified:** 2026-06-02T17:30:00Z
**Status:** GAPS_FOUND
**Re-verification:** Nao — verificacao inicial

---

## Decisao de Verificacao

Esta fase e a ultima do milestone v1.1. Nao ha fases futuras para diferimento (Step 9b nao se aplica). Todos os 4 Success Criteria do ROADMAP sao nao-negociaveis.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidencia |
|---|-------|--------|-----------|
| 1 | Admin pode fazer upload de arquivo e o arquivo fica salvo e acessivel (SC1 — preview no portal do cliente) | ? INCERTO | `has_one_attached :media_file` existe no model (linha 4), `f.file_field :media_file` presente no form (linha 43), `rails_blob_path` usado em show.html.erb e client portal. Verificacao de upload real requer servidor — ver Verificacao Humana #1 |
| 2 | Arte criada sem client_id via form nunca resulta em arte orphan — sistema deriva client_id do contexto (SC2) | VERIFICADO | Selector condicional implementado: quando `arte.client_id.present?` e false, exibe `f.select :client_id` com `Client.order(:name)` e prompt (form linha 49-56). `arte_params` permite `:client_id`. Validacao `validates :client, presence: true` no model impede persistencia sem cliente |
| 3 | Admin nao consegue acessar, editar ou excluir arte de outro cliente mesmo manipulando a URL (SC3) | FALHOU | `set_arte` faz `Arte.find(params[:id])` sem filtro por client. Qualquer ID de arte na URL da acesso. Decisao D-07 do CONTEXT.md aceita isso ("sistema single-admin"), mas SC3 do ROADMAP exige a protecao — conflito entre decisao de implementacao e contrato |
| 4 | Artes listadas no painel sao sempre escopadas ao cliente selecionado, sem vazamento cross-client (SC4) | FALHOU | `index` carrega `Arte.includes(:client).order(scheduled_on: :desc)` sem filtro. Comentario `# Filtering logic can be added here` na linha 12 confirma que o escopamento nao foi implementado |
| 5 | @client disponivel em show, edit, update, destroy, mark_revised via set_arte (ARTE-10 / plano 07-01) | VERIFICADO | `set_arte` linha 60: `@client = @arte.client` — uma linha adicional apos `@arte = Arte.includes(:approval_responses).find(params[:id])`. Commit 09c27b2 confirma. Sintaxe Ruby OK |
| 6 | Erros de :base visiveis no topo do form apos falha de validacao (ARTE-08 / plano 07-02) | VERIFICADO (codigo) | Form linhas 3-9: `if arte.errors[:base].any?` com wrapper `bg-red-50`, iteracao sobre mensagens. Bloco aparece antes do primeiro campo :title (linha 11). Verificacao em runtime requer request real — ver Verificacao Humana #2 |

**Score: 3/6 truths verificadas** (SC3 e SC4 falham; SC1 incerto por necessitar verificacao humana)

---

### Deferred Items

Nenhum. Fase 07 e a ultima do milestone v1.1. Nao ha fases futuras neste roadmap.

---

### Required Artifacts

| Artifact | Esperado | Status | Detalhes |
|----------|----------|--------|---------|
| `app/controllers/admin/artes_controller.rb` | set_arte com `@client = @arte.client` | VERIFICADO | Linha 60: `@client = @arte.client` presente e wired via before_action para show/edit/update/destroy/mark_revised (linha 2). `set_client` intacto na linha 63-64. Sintaxe OK |
| `app/views/admin/artes/_form.html.erb` | Selector condicional `arte.client_id.present?` | VERIFICADO | Linha 49: `if arte.client_id.present?` → hidden_field (linha 50). Else: `f.select :client_id` com `Client.order(:name)` e prompt PT-BR (linha 54) |
| `app/views/admin/artes/_form.html.erb` | Bloco de erros `:base` | VERIFICADO | Linhas 3-9: `if arte.errors[:base].any?` com bg-red-50/border-red-200, iteracao sobre mensagens. Posicionado antes do campo :title (linha 11) |

---

### Key Link Verification

| From | To | Via | Status | Detalhes |
|------|----|-----|--------|---------|
| `artes_controller.rb` | `arte.rb` | `@arte.client (belongs_to :client)` | VERIFICADO | `belongs_to :client` na linha 2 do model. `@client = @arte.client` na linha 60 do controller. Ligacao valida |
| `_form.html.erb` | `arte.rb` | `arte.client_id.present?` e `arte.errors[:base]` | VERIFICADO | `arte.client_id` e atributo do model; `errors.add(:base, ...)` em linhas 22 e 27 do model. Ligacao valida |
| `_form.html.erb` | `artes_controller.rb` | `Arte.new(client: @client)` — quando nil, selector exibido | VERIFICADO | Controller linha 19: `Arte.new(client: @client)`. Quando `@client` e nil, `arte.client_id` e nil → bloco `else` do form exibe selector |
| `artes_controller.rb` (index) | `arte.rb` | Escopamento cross-client | NAO CONECTADO | `Arte.includes(:client).order(scheduled_on: :desc)` sem `where` por cliente. SC4 nao satisfeito |

---

### Data-Flow Trace (Level 4)

| Artifact | Variavel | Fonte | Dados Reais | Status |
|----------|----------|-------|-------------|--------|
| `_form.html.erb` | `arte.client_id` | `Arte.new(client: @client)` no controller; `@client` vem de `set_client` ou params | Arte sem client_id → selector exibido corretamente | FLUINDO (logica condicional valida) |
| `_form.html.erb` | `arte.errors[:base]` | `Arte#media_source_present` e `Arte#only_one_media_source` em arte.rb | `errors.add(:base, ...)` real no model | FLUINDO (verificacao em runtime pendente) |
| `index.html.erb` | `@artes` | `Arte.includes(:client).order(scheduled_on: :desc)` | Retorna TODAS as artes sem filtro | DESCONECTADO do escopo de cliente — SC4 falha |

---

### Behavioral Spot-Checks

| Comportamento | Comando | Resultado | Status |
|---------------|---------|-----------|--------|
| Sintaxe Ruby do controller | `bundle exec ruby -c app/controllers/admin/artes_controller.rb` | "Syntax OK" | PASSOU |
| `@client = @arte.client` presente em set_arte | `grep -n "@client = @arte.client" app/controllers/admin/artes_controller.rb` | Linha 60 | PASSOU |
| set_client permanece intacto | `grep -n "Client.find_by" app/controllers/admin/artes_controller.rb` | Linha 64 | PASSOU |
| Selector condicional presente | `grep -n "arte.client_id.present?" app/views/admin/artes/_form.html.erb` | Linha 49 | PASSOU |
| f.select com Client.order | `grep -n "Client.order" app/views/admin/artes/_form.html.erb` | Linha 54 | PASSOU |
| Bloco de erros :base presente | `grep -n "arte.errors\[:base\]" app/views/admin/artes/_form.html.erb` | Linhas 3 e 5 | PASSOU |
| Bloco de erros antes do campo :title | Linha erros=3, linha :title=11 | Correto (3 < 11) | PASSOU |
| hidden_field fora da div flex gap-2 | `grep -A5 "flex gap-2" _form.html.erb` | Apenas submit e link Cancelar na div | PASSOU |
| Index action sem filtro de cliente | `grep "where\|client_id" artes_controller.rb index` | Nenhum filtro | FALHOU (SC4) |
| Comentario de divida em arquivo modificado | `grep "Filtering logic can be added"` | Linha 12 do controller | BLOQUEADOR |

---

### Probe Execution

Step 7c: PULADO — sem arquivos `scripts/*/tests/probe-*.sh` neste projeto.

---

### Requirements Coverage

| Requisito | Plano | Descricao em REQUIREMENTS.md | Status | Evidencia |
|-----------|-------|-------------------------------|--------|---------|
| ARTE-08 | 07-02 | Admin pode fazer upload de arquivo ao criar uma arte e o arquivo fica salvo e acessivel via ActiveStorage | INCERTO | `has_one_attached :media_file`, `f.file_field :media_file`, bloco de erros :base presente. Verificacao de upload real requer servidor — humano necessario |
| ARTE-09 | 07-02 | Arte nao pode ser criada sem client_id valido — sistema garante que o client_id vem do contexto correto | VERIFICADO (codigo) | Selector condicional implementado; `arte_params` permite :client_id; model valida presenca. Fluxo de UI requer verificacao humana |
| ARTE-10 | 07-01 | set_arte verifica que a arte pertence ao cliente esperado, evitando acesso cross-client | PARCIALMENTE — FALHOU | `@client = @arte.client` expoe o contexto, mas nao ha verificacao de pertencimento. Arte.find(params[:id]) permite acesso a qualquer arte por URL. REQUIREMENTS.md diz "evitando acesso cross-client" — nao implementado |

**Nota sobre ARTE-10:** O REQUIREMENTS.md diz explicitamente "evitando acesso cross-client". O plano 07-01 interpretou ARTE-10 como apenas "expor @client via set_arte", descartando a verificacao de pertencimento com base na decisao D-07 ("sistema single-admin"). Ha uma divergencia entre o requisito original e a implementacao escolhida.

---

### Anti-Patterns Found

| Arquivo | Linha | Padrao | Severidade | Impacto |
|---------|-------|--------|------------|---------|
| `app/controllers/admin/artes_controller.rb` | 12 | `# Filtering logic can be added here` — marcador de trabalho incompleto sem referencia a issue ou PR | BLOQUEADOR | Confirma que SC4 (escopamento de listagem) nao foi implementado; viola gate de marcadores de divida |

---

### Human Verification Required

#### 1. Upload de Arquivo via ActiveStorage

**Test:** Navegar para /admin/artes/new, selecionar um cliente no dropdown, preencher titulo e data, clicar em "Upload de arquivo", selecionar um arquivo de imagem real, submeter o form.
**Expected:** Arte e criada com sucesso. Ao acessar o show da arte no admin, aparece link para download. Ao acessar o portal do cliente, a imagem e exibida via `image_tag rails_blob_path(...)`.
**Why human:** ActiveStorage.attach, rails_blob_path e armazenamento local requerem servidor rodando com DB e disco disponiveis.

#### 2. Exibicao de Erros :base no Form

**Test:** Navegar para /admin/artes/new, selecionar um cliente, preencher os campos obrigatorios mas NAO selecionar nenhuma midia (nem upload nem link), submeter o form.
**Expected:** Form e re-exibido com mensagem "Precisa de arquivo ou link externo" visivelmente no topo, dentro de uma caixa com fundo vermelho claro (bg-red-50).
**Why human:** Re-renderizacao do form apos falha de validacao requer request HTTP real.

#### 3. Selector de Cliente Exibido sem client_id na URL

**Test:** Navegar diretamente para /admin/artes/new (sem parametro ?client_id). Verificar que o form exibe o campo "Cliente" com dropdown contendo todos os clientes cadastrados e prompt "Selecione o cliente". Selecionar um cliente, preencher demais campos, fazer upload de arquivo, submeter.
**Expected:** Arte e criada com client_id correto (correspondente ao cliente selecionado no dropdown). Sem erro de validacao de cliente.
**Why human:** Comportamento condicional `arte.client_id.present?` depende de `@client` nil em runtime.

#### 4. Fluxo via Pagina do Cliente (hidden_field)

**Test:** Navegar para /admin/clients/:id (pagina de um cliente), clicar em "Nova Arte". Verificar que o form NAO exibe o dropdown de clientes, mas sim um campo oculto com o client_id correto. Criar a arte normalmente.
**Expected:** Form exibe apenas os campos visiveis sem o selector de cliente. Arte criada com client_id do cliente correto.
**Why human:** Comportamento condicional depende de `arte.client_id.present?` ser true em runtime com params da URL.

---

### Gaps Summary

**Dois blockers impedem o fechamento desta fase:**

**BLOCKER 1 — SC3 nao implementado (ARTE-10 parcialmente interpretado):**
`set_arte` expoe `@client = @arte.client` mas nao ha verificacao de pertencimento. Qualquer arte pode ser acessada por qualquer URL `/admin/artes/:id`. O REQUIREMENTS.md define ARTE-10 como "evitando acesso cross-client" e o ROADMAP SC3 diz "admin nao consegue acessar arte de outro cliente mesmo manipulando a URL". A decisao D-07 do CONTEXT.md ("sistema single-admin, sem restricao necessaria") diverge do contrato do ROADMAP. Esta e uma decisao que o desenvolvedor precisa tomar: aceitar o desvio (adicionar override explicito) ou implementar a verificacao.

**BLOCKER 2 — SC4 nao implementado e comentario de divida:**
O `index` action carrega todas as artes sem filtro. O comentario `# Filtering logic can be added here` (linha 12) e um marcador de trabalho incompleto sem referencia rastreavel. O ROADMAP SC4 exige escopamento — nem a logica de filtragem foi iniciada.

**Opcoes para o desenvolvedor:**

Para SC3: Se o sistema e genuinamente single-admin e cross-client nao e uma preocupacao de seguranca real, adicionar um override explicito no VERIFICATION.md e atualizar REQUIREMENTS.md/ROADMAP para refletir a decisao. Caso contrario, implementar: `@arte = Arte.includes(:approval_responses).find_by!(id: params[:id])` seguido de verificacao de `@arte.client_id == @client.id` (quando @client disponivel).

Para SC4: Implementar filtragem minima no index — ex: `@artes = params[:client_id].present? ? Arte.where(client_id: params[:client_id]) : Arte.all`, e remover ou referenciar o comentario.

---

_Verified: 2026-06-02T17:30:00Z_
_Verifier: Claude (gsd-verifier)_
