---
phase: 07-art-upload-client-scoping-fix
reviewed: 2026-06-02T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - app/controllers/admin/artes_controller.rb
  - app/views/admin/artes/_form.html.erb
findings:
  critical: 3
  warning: 3
  info: 1
  total: 7
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Revisao dos dois arquivos apos a implementacao do plano 07-03 (SC3 e SC4). Os objetivos do plano foram atingidos: `set_arte` escopeia por `@client` quando disponivel, e `index` filtra por `params[:client_id]`. No entanto, a ampliacao de `before_action :set_client` para show/edit/update/destroy/mark_revised introduziu um novo blocker: `set_client` usa `find_by` que retorna `nil` sem redirecionar, fazendo `set_arte` cair no branch irrestrito sempre que `client_id` estiver ausente ou invalido — o que neutraliza a protecao cross-client do SC3. As rotas de `artes` nao sao nested sob `clients` (`config/routes.rb:14`), portanto `client_id` e um query param opcional, nao obrigatorio — a protecao so atua quando o chamador o inclui. Dois outros blockers preexistentes permanecem: `destroy` ignora retorno booleano, e `media_source` e descartado silenciosamente pelo servidor enquanto o formulario cria expectativa de exclusao mutua entre arquivo e link. Tres warnings persistem.

---

## Critical Issues

### CR-01: `set_client` retorna `nil` silenciosamente — protecao cross-client do SC3 pode ser bypassada omitindo `client_id`

**File:** `app/controllers/admin/artes_controller.rb:70-72`

**Issue:** `set_client` usa `Client.find_by(id: params[:client_id])`, que retorna `nil` sem redirecionar quando `client_id` esta ausente ou invalido. Agora que `set_client` cobre show/edit/update/destroy/mark_revised (linha 2), qualquer requisicao a `/admin/artes/:id` sem `client_id` resulta em `@client = nil`. O `set_arte` (linhas 61-68) interpreta `@client` nil como ausencia intencional de escopo e executa `Arte.includes(:approval_responses).find(params[:id])` sem restricao de cliente.

Isso e o caminho padrao: as rotas nao sao nested (`resources :artes` standalone em `config/routes.rb:14`), entao `client_id` e opcional. Os links gerados pela view nao incluem `client_id` — por exemplo, `admin_arte_path(arte)` em `index.html.erb:26` gera `/admin/artes/:id` sem query param. Qualquer acesso normal pelo painel navega pelo branch irrestrito. A protecao do SC3 so funciona no caso especial em que o chamador inclui `client_id` na URL — que nao ocorre organicamente na UI atual.

**Fix:** Adicionar guard em `set_client` para redirecionar quando `client_id` e fornecido mas invalido:

```ruby
def set_client
  return unless params[:client_id].present?
  @client = Client.find_by(id: params[:client_id])
  unless @client
    redirect_to admin_artes_path, alert: "Cliente nao encontrado." and return
  end
end
```

Se o requisito real e que show/edit/update/destroy sempre exijam contexto de cliente, a correcao estrutural e tornar as rotas nested:

```ruby
# config/routes.rb
namespace :admin do
  resources :clients do
    resources :artes
  end
  resources :artes  # manter para acesso direto por ID se necessario
end
```

---

### CR-02: `destroy` ignora retorno booleano — exclusao falha silenciosamente

**File:** `app/controllers/admin/artes_controller.rb:45-48`

**Issue:** `@arte.destroy` retorna `false` (sem levantar excecao) quando um callback `before_destroy` impede a exclusao — por exemplo, se Active Storage falhar ao remover o blob com callback configurado. O redirect com `notice: "Arte excluida com sucesso."` e incondicional: o admin recebe feedback de sucesso mesmo que o registro ainda exista no banco.

**Fix:**
```ruby
def destroy
  if @arte.destroy
    redirect_to admin_artes_path, notice: "Arte excluida com sucesso."
  else
    redirect_to admin_arte_path(@arte), alert: "Nao foi possivel excluir a arte."
  end
end
```

---

### CR-03: `media_source` descartado pelo servidor — exclusao mutua de midia nao funciona em update

**File:** `app/views/admin/artes/_form.html.erb:37-38` / `app/controllers/admin/artes_controller.rb:74-76`

**Issue:** O formulario envia `arte[media_source]=upload` ou `arte[media_source]=link` via radio buttons. O campo nao esta listado em `arte_params` (linha 75), entao Rails descarta silenciosamente. O impacto pratico em update: se uma arte tem `media_file` anexado e o admin seleciona "Link externo" no radio e preenche `external_url`, o Stimulus esconde o campo de arquivo visualmente, mas o arquivo pre-existente nao e desanexado — o servidor nunca recebe instrucao para purgar. A validacao `only_one_media_source` no model (`arte.rb:26-28`) rejeita o save com erro "Use arquivo OU link externo, nao ambos". O admin ve um erro sem causa aparente, pois na UI apenas o campo de link estava visivel.

**Fix — honrar o radio no controller:**
```ruby
def update
  @arte.assign_attributes(arte_params)
  case params.dig(:arte, :media_source)
  when "link"
    @arte.media_file.purge_later if @arte.media_file.attached?
  when "upload"
    @arte.external_url = nil
  end
  if @arte.save
    redirect_to admin_arte_path(@arte), notice: "Arte atualizada com sucesso."
  else
    render :edit, status: :unprocessable_entity
  end
end
```

O mesmo tratamento deve ser aplicado em `create`. Alternativamente, remover os radio buttons e instruir o admin a limpar o campo nao utilizado antes de salvar.

---

## Warnings

### WR-01: Estado inicial dos radio buttons indefinido em nova arte — campos de midia ficam ocultos

**File:** `app/views/admin/artes/_form.html.erb:37-45`

**Issue:** Em uma arte nova (sem `media_file` e sem `external_url`), ambas as condicoes `checked: arte.media_file.attached?` (linha 37) e `checked: arte.external_url.present?` (linha 38) sao `false`. Nenhum radio fica selecionado. O Stimulus `connect()` chama `toggleFields()`, que verifica ambos como `false` e nao faz nada. Os dois divs (linhas 41 e 45) tem classe `hidden` como estado inicial e permanecem ocultos. O admin ve o formulario sem nenhuma opcao de midia visivel.

Confirmado lendo o Stimulus controller em `app/javascript/controllers/media_type_toggle_controller.js`: `toggleFields()` so exibe um dos campos se um dos radios estiver checked — sem radio selecionado, ambos ficam hidden.

**Fix:** Pre-selecionar "Upload" como padrao para artes novas:
```erb
<label>
  <%= f.radio_button :media_source, :upload,
      checked: arte.media_file.attached? || arte.external_url.blank?,
      data: { action: "media-type-toggle#selectUpload",
              media_type_toggle_target: "uploadRadio" } %>
  Upload de arquivo
</label>
```

---

### WR-02: Botao "Editar" oculto para artes `revised?` e `change_requested?` — inconsistencia com `check_editable`

**File:** `app/views/admin/artes/show.html.erb:17`

**Issue:** `check_editable` no controller (linha 78-81) autoriza edicao para `pending? || revised? || change_requested?`. O botao "Editar" na view so aparece quando `@arte.pending?`. Artes com status `revised` ou `change_requested` podem ser editadas (controller as aceita), mas a UI nao expoe esse caminho. O admin nao tem como editar uma arte que precisa de revisao pela UI — precisa conhecer a URL diretamente.

**Fix:**
```erb
<%= link_to "Editar", edit_admin_arte_path(@arte), class: "btn btn-secondary" if @arte.pending? || @arte.revised? || @arte.change_requested? %>
```

---

### WR-03: `index` filtra por `params[:client_id]` sem verificar existencia do cliente — falha silenciosa

**File:** `app/controllers/admin/artes_controller.rb:8-12`

**Issue:** `Arte.where(client_id: params[:client_id])` retorna colecao vazia sem distinguir "cliente existe mas nao tem artes" de "cliente nao existe". Operacionalmente o admin nao recebe feedback ao usar um `client_id` invalido — a pagina carrega vazia sem aviso. Em contexto single-admin o risco de seguranca e aceito (D-07), mas a ausencia de feedback pode causar confusao na operacao.

**Fix:**
```ruby
def index
  if params[:client_id].present?
    @filtered_client = Client.find_by(id: params[:client_id])
    unless @filtered_client
      redirect_to admin_artes_path, alert: "Cliente nao encontrado." and return
    end
    @artes = @filtered_client.artes.includes(:client).order(scheduled_on: :desc)
  else
    @artes = Arte.includes(:client).order(scheduled_on: :desc)
  end
  @clients = Client.all
  @status_options = Arte.statuses.keys
  @platform_options = Arte.platforms.keys
end
```

---

## Info

### IN-01: `arte_params` inclui `:admin_reply` em `create` — campo sem correspondente no formulario de criacao

**File:** `app/controllers/admin/artes_controller.rb:74-76`

**Issue:** `:admin_reply` esta em `arte_params` e e aceito em `create` e `update`. O uso em `update` e legitimo — o formulario em `show.html.erb:33-42` salva `admin_reply` via PATCH. Em `create` o campo nao tem correspondente no formulario, mas continua sendo aceito. Em um contexto single-admin isso e de baixo risco, mas a separacao de intencao seria mais limpa com um metodo dedicado para o update de `admin_reply`.

**Fix (opcional):** Remover `:admin_reply` de `arte_params` e criar `arte_reply_params` usado exclusivamente em `update` para o contexto de resposta.

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
