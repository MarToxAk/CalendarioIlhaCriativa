---
phase: 07-art-upload-client-scoping-fix
reviewed: 2026-06-02T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - app/controllers/admin/artes_controller.rb
  - app/views/admin/artes/_form.html.erb
findings:
  critical: 2
  warning: 4
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

Revisão dos dois arquivos alterados na fase 07 (upload de artes + client scoping). O controller possui dois problemas críticos: o `set_client` falha silenciosamente quando `client_id` está ausente, e a ação `destroy` não verifica o retorno do `destroy` — permitindo que uma falha de exclusão passe despercebida. O formulário possui dois problemas que se combinam para causar comportamento incorreto no caso de edição: os radio buttons de `media_source` são enviados ao servidor mas não estão no `arte_params` permitlist, e a lógica de pré-seleção dos radio buttons pode deixar nenhum botão selecionado quando nem `media_file` está anexado nem `external_url` está preenchido (arte nova em branco), travando o Stimulus controller.

---

## Critical Issues

### CR-01: `set_client` falha silenciosamente — arte pode ser criada sem cliente

**File:** `app/controllers/admin/artes_controller.rb:63-65`

**Issue:** `set_client` usa `find_by(id: params[:client_id])`, que retorna `nil` sem levantar erro quando `client_id` está ausente ou inválido. A action `new` então instancia `Arte.new(client: nil)` e a action `create` chama `Arte.new(arte_params)` onde `arte_params` pode ter `client_id: nil` ou `client_id` totalmente ausente se o campo foi manipulado no formulário. O `set_client` só é chamado em `new` e `create` mas o resultado `@client` não é validado — o fluxo continua sem redirecionar ou alertar. A validação de modelo `validates :client, presence: true` vai capturar o caso no `save`, mas o `@arte.client` que aparece no formulário de nova arte (via `Arte.new(client: @client)`) fica `nil`, fazendo o campo hidden field do `client_id` ser vazio e potencialmente confundindo a view.

Mais grave: quando a rota `new_admin_arte_path` é acessada **sem** `client_id` (como no link da index, linha 6 de `index.html.erb`), `@client` é `nil` e `Arte.new(client: nil)` é criado. O formulário renderiza a seção de seleção de cliente (`arte.client_id.present?` é false), mas se o usuário não selecionar cliente e submeter, `arte_params` terá `client_id: ""` que passa pelo `permit` e chega no model como `nil`, gerando erro de validação. Isso é o fluxo esperado — mas não há feedback antes do submit.

O problema crítico real: **não há guard contra `@client` nil em `new`/`create`**. Se o admin acessa `new_admin_arte_path` sem autenticação num cenário futuro, ou se `Client.find_by` retorna nil por ID adulterado, o controller continua sem verificar. Adicionar um guard explícito torna a intenção clara e evita erros 500 se `@client` for usado de forma não-nil-safe em views futuras.

**Fix:**
```ruby
def set_client
  return unless params[:client_id].present?
  @client = Client.find_by(id: params[:client_id])
  unless @client
    redirect_to admin_artes_path, alert: "Cliente não encontrado." and return
  end
end
```

---

### CR-02: `destroy` ignora o retorno — falha de exclusão silenciosa

**File:** `app/controllers/admin/artes_controller.rb:42-45`

**Issue:** `@arte.destroy` pode retornar `false` se um callback `before_destroy` ou validação impedir a exclusão (p.ex., se Active Storage falhar ao deletar o blob). O código atual redireciona com `notice: "Arte excluída com sucesso."` incondicionalmente, mesmo que a exclusão tenha falhado. O usuário recebe uma mensagem falsa de sucesso enquanto o registro permanece no banco.

**Fix:**
```ruby
def destroy
  if @arte.destroy
    redirect_to admin_artes_path, notice: "Arte excluída com sucesso."
  else
    redirect_to admin_arte_path(@arte), alert: "Não foi possível excluir a arte."
  end
end
```

---

## Warnings

### WR-01: `media_source` enviado no POST mas não no `arte_params` — dado descartado silenciosamente

**File:** `app/views/admin/artes/_form.html.erb:37-38` / `app/controllers/admin/artes_controller.rb:68`

**Issue:** O formulário inclui `f.radio_button :media_source, :upload` e `f.radio_button :media_source, :link`. Esses campos geram `arte[media_source]=upload` ou `arte[media_source]=link` no POST. O `arte_params` em `artes_controller.rb:68` **não inclui `:media_source`** na lista de `permit`. O Rails descarta o parâmetro silenciosamente (com `UnpermittedParameters` em log no ambiente de desenvolvimento). Mais importante: a lógica de determinar qual mídia usar (arquivo ou link) depende somente dos campos `media_file` e `external_url` — o `media_source` radio não tem efeito funcional real. Se um usuário seleciona "Link externo" no radio mas havia um arquivo previamente anexado, ambos coexistem até a validação `only_one_media_source` barrar. Isso é confuso: o rádio cria uma expectativa de exclusão mútua gerenciada pelo servidor, mas o servidor ignora o campo.

**Fix:** Ou adicionar `:media_source` ao `permit` e usar seu valor para limpar o campo oposto no controller, ou remover os radio buttons e deixar apenas a lógica visual do Stimulus (já que o modelo valida `only_one_media_source`):

```ruby
# Opção A: honrar o radio no controller
def create
  @arte = Arte.new(arte_params_without_media_source)
  if params.dig(:arte, :media_source) == "upload"
    @arte.external_url = nil
  elsif params.dig(:arte, :media_source) == "link"
    @arte.media_file.detach if @arte.media_file.attached?
  end
  # ...
end
```

---

### WR-02: Estado inicial dos radio buttons indefinido em nova arte — Stimulus travado

**File:** `app/views/admin/artes/_form.html.erb:37-38`

**Issue:** Em uma arte **nova** (sem `media_file` anexado e sem `external_url`), ambas as condições `checked: arte.media_file.attached?` e `checked: arte.external_url.present?` são `false`. Nenhum radio button fica selecionado. O Stimulus controller (`media_type_toggle_controller.js`) chama `toggleFields()` no `connect()`, que verifica `this.uploadRadioTarget.checked` e `this.linkRadioTarget.checked` — ambos `false` — e **não faz nada**: os dois campos (`uploadField`, `linkField`) ficam com a classe CSS `hidden` conforme definido nas linhas 41 e 45. O resultado: o admin vê o formulário sem nenhuma opção de mídia visível, sem indicação do que fazer.

**Fix:** Definir um estado inicial explícito para artes novas — pré-selecionar "Upload" como padrão:

```erb
<label>
  <%= f.radio_button :media_source, :upload,
      checked: arte.media_file.attached? || arte.external_url.blank?,
      data: { action: "media-type-toggle#selectUpload",
              media_type_toggle_target: "uploadRadio" } %>
  Upload de arquivo
</label>
<label>
  <%= f.radio_button :media_source, :link,
      checked: arte.external_url.present?,
      data: { action: "media-type-toggle#selectLink",
              media_type_toggle_target: "linkRadio" } %>
  Link externo
</label>
```

---

### WR-03: `show.html.erb` exibe botão "Editar" apenas para `pending?`, mas `check_editable` permite `revised?` e `change_requested?`

**File:** `app/views/admin/artes/show.html.erb:17` (referenciado por contexto do controller linha 71-75)

**Issue:** O guard `check_editable` no controller autoriza edição para `pending? || revised? || change_requested?`, mas o botão "Editar" na view só aparece quando `@arte.pending?`. Artes com status `revised` ou `change_requested` **podem** ser editadas (o controller as aceita), mas a UI não expõe esse caminho. O admin fica sem forma de editar uma arte que precisa de revisão, a menos que saiba a URL diretamente. Isso é uma inconsistência entre controller e view — o comportamento correto está no controller mas está escondido na view.

**Fix:**
```erb
<%= link_to "Editar", edit_admin_arte_path(@arte), class: "btn btn-secondary" if @arte.pending? || @arte.revised? || @arte.change_requested? %>
```

---

### WR-04: `arte_params` inclui `:admin_reply` — risco de mass assignment não intencional

**File:** `app/controllers/admin/artes_controller.rb:68`

**Issue:** O campo `:admin_reply` está incluído em `arte_params` e é, portanto, atualizável via as actions `create` e `update`. Se um cliente interno manipular o formulário de criação de arte via DevTools para incluir `arte[admin_reply]=...`, o campo será aceito. Embora o painel seja admin-only e o `require_authentication` proteja o acesso, `admin_reply` semanticamente deveria ser editável apenas em contexto específico (a ação de resposta ao cliente), não na criação/edição geral da arte.

O risco é baixo num contexto puramente admin, mas a separação de intenção é importante — especialmente se o controller vier a ser reutilizado ou se as permissões de admin forem granularizadas no futuro.

**Fix:** Separar os params por action:
```ruby
def arte_params
  params.require(:arte).permit(:title, :caption, :scheduled_on, :approval_deadline,
                               :external_url, :platform, :media_type, :client_id, :media_file)
end

def arte_reply_params
  params.require(:arte).permit(:admin_reply)
end
```

---

## Info

### IN-01: Comentário obsoleto no `index` action

**File:** `app/controllers/admin/artes_controller.rb:12`

**Issue:** `# Filtering logic can be added here` é um comentário de placeholder que não agrega valor ao código atual. O `index` não tem nenhuma lógica de filtro implementada e a presença de `@clients`, `@status_options` e `@platform_options` sem uso real na action (provavelmente para um filtro futuro) indica trabalho inacabado que pode confundir revisores futuros.

**Fix:** Remover o comentário de placeholder, ou implementar o filtro e remover a nota. Se for intencional (work-in-progress), usar um TODO com contexto: `# TODO: implementar filtro por cliente/status/plataforma`.

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
