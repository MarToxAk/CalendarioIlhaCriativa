---
phase: 02-admin-auth-client-management
reviewed: 2026-05-25T00:00:00Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - app/assets/tailwind/application.css
  - app/controllers/admin/base_controller.rb
  - app/controllers/admin/clients_controller.rb
  - app/javascript/controllers/copy_controller.js
  - app/javascript/controllers/dropdown_controller.js
  - app/javascript/controllers/modal_controller.js
  - app/views/admin/clients/_actions_menu.html.erb
  - app/views/admin/clients/_client_row.html.erb
  - app/views/admin/clients/_confirm_modal.html.erb
  - app/views/admin/clients/_copy_button.html.erb
  - app/views/admin/clients/edit.html.erb
  - app/views/admin/clients/_form.html.erb
  - app/views/admin/clients/index.html.erb
  - app/views/admin/clients/new.html.erb
  - app/views/admin/clients/_readonly_field.html.erb
  - app/views/admin/clients/show.html.erb
  - app/views/admin/clients/_status_badge.html.erb
  - app/views/admin/shared/_sidebar.html.erb
  - app/views/layouts/admin.html.erb
  - config/routes.rb
  - db/migrate/20260525052827_add_password_plain_to_clients.rb
  - db/schema.rb
  - test/controllers/admin/clients_controller_test.rb
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-25
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Esta revisão cobre o módulo de gerenciamento de clientes do admin (CRUD completo, modais de confirmação, controllers Stimulus, migrações e testes). O código tem estrutura sólida e boas práticas de acessibilidade, mas apresenta quatro falhas críticas: armazenamento de senha em texto simples no banco de dados (risco de segurança grave), XSS via `raw()` em partial de modal, desfuncionamento total do botão "Desativar cliente" no menu de ações da listagem, e falha silenciosa no modal de desativação na tela `show` (o form é enviado sem o parâmetro `active: false`). Há também vazamentos de event listener no modal controller e inconsistências menores de nomes de variáveis de layout.

---

## Critical Issues

### CR-01: Senha armazenada em texto simples no banco de dados

**File:** `db/migrate/20260525052827_add_password_plain_to_clients.rb:3`
**Issue:** A migração adiciona a coluna `password_plain :string` na tabela `clients`, e o controller salva explicitamente a senha em texto puro nessa coluna (`password_plain: params_with_plain[:password]`). A view `show` exibe e permite copiar esse valor. Armazenar senhas de usuários em texto simples é uma vulnerabilidade grave: qualquer dump de banco de dados, backup, query de suporte, ou acesso não autorizado ao banco expõe todas as senhas imediatamente sem necessidade de força bruta.

**Fix:** Se o requisito de negócio é exibir a senha para o admin (para repasse ao cliente), a solução correta é criptografar o valor com uma chave simétrica controlada pela aplicação, não armazenar texto puro. Uma alternativa mais simples: ao criar/atualizar, gerar e exibir a senha gerada apenas uma vez (via flash message ou página de confirmação), sem persistir o texto puro. Se o campo já existe em produção, o dado deve ser tratado como comprometido e os clientes devem trocar suas senhas.

```ruby
# Exemplo de abordagem alternativa: exibir senha apenas no flash de criação
# No controller#create, após @client.save:
redirect_to admin_client_path(@client),
  notice: "Cliente cadastrado. Senha de acesso: #{plain_password} — anote agora, não será exibida novamente."
# E remover completamente a coluna password_plain e sua lógica de persistência.
```

---

### CR-02: XSS via `raw()` em `_confirm_modal`

**File:** `app/views/admin/clients/_confirm_modal.html.erb:33`
**Issue:** O corpo do modal é renderizado com `<%= raw(body) %>`. O conteúdo de `body` é construído nas views com interpolação Ruby direta (string `"#{@client.name}"`), sem escape. Se o nome de um cliente contiver HTML ou JavaScript (ex: `<img src=x onerror=alert(1)>`), o código será executado no browser do admin. Um cliente cadastrado com nome malicioso pode realizar XSS armazenado contra todos os administradores que visualizarem a tela `show`.

**Exemplo do vetor:** `show.html.erb` linha 25:
```erb
body: "Desativar <strong>#{@client.name}</strong> bloqueará..."
```
O valor `@client.name` não é escapado antes de ser interpolado na string Ruby, portanto não é protegido pelo auto-escape do ERB.

**Fix:** Substituir `raw(body)` por `<%= body %>` (que faz auto-escape) e garantir que o conteúdo HTML seguro seja gerado com `html_escape` + `content_tag` ou marcado explicitamente com `.html_safe` apenas após escapar os dados dinâmicos:

```erb
<%# Em _confirm_modal.html.erb — remover raw() %>
<p id="<%= id %>-desc" class="text-sm text-slate-600 leading-relaxed mt-3">
  <%= body %>
</p>
```

```erb
<%# Em show.html.erb — escapar o nome antes de interpolar %>
body: "Desativar <strong>#{html_escape(@client.name)}</strong> bloqueará o acesso ao portal imediatamente. O cliente não conseguirá acessar o calendário até ser reativado.".html_safe,
```

O mesmo padrão se aplica ao body do modal `rotate-modal` na linha 103.

---

### CR-03: Botão "Desativar cliente" no menu de ações não realiza nenhuma ação

**File:** `app/views/admin/clients/_actions_menu.html.erb:29`
**Issue:** O link "Desativar cliente" no dropdown da listagem aponta para `"#"` e dispara `click->dropdown#toggle` — ou seja, apenas fecha o menu. Não há nenhuma lógica de desativação, navegação para confirmação, ou envio de form. Um admin que clicar em "Desativar cliente" pelo menu de ações na lista de clientes terá o menu fechado e nada acontecerá — o cliente permanece ativo sem nenhum feedback de erro.

**Fix:** Duas opções aceitáveis:
1. Remover o item do menu e orientar o admin a usar o botão na tela `show` (mais simples).
2. Implementar a ação corretamente com `button_to` apontando para `admin_client_path` com `{ client: { active: false } }`:

```erb
<%# Opção 2 — substituir o link fantasma por um button_to funcional %>
<% if client.active %>
  <%= button_to admin_client_path(client),
        method: :patch,
        params: { client: { active: false } },
        data: { turbo_confirm: "Desativar #{client.name}? O acesso ao portal será bloqueado imediatamente." },
        class: "w-full text-left px-4 py-2 text-sm text-[#EE3537] hover:bg-gray-50 transition-colors bg-transparent border-0 cursor-pointer" do %>
    Desativar cliente
  <% end %>
<% else %>
```

---

### CR-04: Modal de desativação em `show` envia form sem o parâmetro `active: false`

**File:** `app/views/admin/clients/show.html.erb:22-30`
**Issue:** O modal de confirmação "Desativar cliente" é renderizado via `_confirm_modal` com `form_action: admin_client_path(@client)` e `method: :patch`, mas sem nenhum parâmetro de payload. A partial `_confirm_modal` cria um `form_with` com apenas um botão submit — nenhum campo hidden com `active: false`. Portanto, quando o admin confirma a desativação, o PATCH é enviado ao servidor com `client_params` vazio (sem `active`). O controller `update` não recebe `active`, então o cliente não é desativado. O flash de sucesso "foi desativado" nunca é acionado — na prática, a ação de desativação via modal está completamente quebrada.

Contraste com a reativação (linha 34-37), que funciona corretamente porque usa `button_to` com `params: { client: { active: true } }`.

**Fix:** Adicionar suporte a `params` opcionais na partial `_confirm_modal`, ou incluir campos hidden explícitos no form:

```erb
<%# Em _confirm_modal.html.erb — adicionar suporte a params opcionais %>
<% extra_params = local_assigns.fetch(:extra_params, {}) %>
...
<%= form_with url: form_action, method: method do |f| %>
  <% extra_params.each do |key, value| %>
    <%= hidden_field_tag key, value %>
  <% end %>
  <%= f.submit confirm_label, class: "..." %>
<% end %>
```

```erb
<%# Em show.html.erb — passar o parâmetro de desativação %>
<%= render "confirm_modal",
      id: "deactivate-modal",
      ...
      form_action: admin_client_path(@client),
      method: :patch,
      extra_params: { "client[active]" => "false" } %>
```

---

## Warnings

### WR-01: Vazamento de event listener no `modal_controller.js` quando desconectado enquanto aberto

**File:** `app/javascript/controllers/modal_controller.js:65-67`
**Issue:** O método `disconnect()` remove apenas o listener `keydown` do documento. Se o modal for destruído enquanto estiver aberto (ex: navegação Turbo enquanto o modal está visível), o listener `boundFocusTrap` adicionado ao `overlayTarget` nunca é removido (linha 24 em `open()`), pois o `overlayTarget` pode não existir mais. Além disso, `this.boundKeydown` é inicializado no `connect()` mas não está vinculado (`bind`) ao contexto — é uma arrow function, então funciona, mas o padrão de inicialização no `connect()` sem adicionar ao documento é estranho (o listener só é adicionado em `open()`). Se `disconnect()` é chamado sem `close()` ter sido chamado antes, o listener de `keydown` no documento também pode vazar dependendo do timing.

**Fix:**
```javascript
disconnect() {
  // Garantir limpeza completa independente do estado
  document.removeEventListener("keydown", this.boundKeydown)
  if (this.hasOverlayTarget) {
    this.overlayTarget.removeEventListener("keydown", this.boundFocusTrap)
  }
}
```

---

### WR-02: `client_params` permite que clientes externos enviem `password_plain` diretamente

**File:** `app/controllers/admin/clients_controller.rb:60`
**Issue:** A whitelist de parâmetros inclui `:password_plain` explicitamente:
```ruby
params.require(:client).permit(:name, :password, :password_plain, :active)
```
Isso significa que um request PATCH forjado com `client[password_plain]=qualquer_valor` pode sobrescrever o campo `password_plain` no banco sem passar pela lógica de sincronização do controller (que copia `:password` para `:password_plain`). Embora a rota exija autenticação de admin, o campo deveria ser gerenciado exclusivamente pelo controller, nunca aceito diretamente do form.

**Fix:** Remover `:password_plain` do `permit()` e sempre derivar o valor de `password` no controller:
```ruby
def client_params
  params.require(:client).permit(:name, :password, :active)
end

# No create e update, sincronizar manualmente:
def sync_password_plain(attrs)
  return attrs unless attrs[:password].present?
  attrs.merge(password_plain: attrs[:password])
end
```

---

### WR-03: `update` não atualiza `password_plain` quando a senha é alterada

**File:** `app/controllers/admin/clients_controller.rb:31-44`
**Issue:** Na action `update`, a lógica de filtro (`filtered`) rejeita `password` e `password_plain` apenas se estiverem em branco. Se uma nova senha é fornecida, `password` é incluído em `filtered` e a senha hasheada (`password_digest`) é atualizada via `has_secure_password`. Porém, diferente do `create`, a action `update` não faz a sincronização `password_plain: params[:password]`. Portanto, após atualizar a senha de um cliente, `password_plain` continua mostrando a senha anterior na tela `show`.

**Fix:**
```ruby
def update
  was_active = @client.active
  filtered = client_params.reject { |k, v| ["password", "password_plain"].include?(k) && v.blank? }
  # Sincronizar password_plain quando password for alterado
  if filtered[:password].present?
    filtered = filtered.merge(password_plain: filtered[:password])
  end
  if @client.update(filtered)
    ...
  end
end
```

---

### WR-04: `current_page?` com paths `"#"` no sidebar gera matches falsos

**File:** `app/views/admin/shared/_sidebar.html.erb:22`
**Issue:** Os itens do nav com `path: "#"` (Aprovações, Calendário, Configurações) são passados ao helper `current_page?("#")`. No Rails, `current_page?` compara a path atual contra o argumento. Se a URL atual tiver um fragment identifier, isso pode causar comportamento inesperado. Mais importante: quando o usuário está em qualquer tela e a URL termina com `#`, o item incorreto ficará marcado como ativo.

**Fix:** Usar `nil` ou uma convenção explícita para items desabilitados, e verificar antes de aplicar o estilo ativo:
```ruby
nav_items = [
  { label: "Dashboard",     path: admin_root_path },
  { label: "Aprovações",    path: nil },
  { label: "Clientes",      path: admin_clients_path },
  { label: "Calendário",    path: nil },
  { label: "Configurações", path: nil },
]
...
active = item[:path] && current_page?(item[:path])
```

---

### WR-05: `update` não tem proteção de CSRF adequada para o botão "Reativar" no actions_menu

**File:** `app/views/admin/clients/_actions_menu.html.erb:34-38`
**Issue:** O `button_to` para reativar cliente na linha 34 usa `admin_client_path(client, client: { active: true })` com os parâmetros na query string da URL, não no body do form. Em Rails, `button_to` com uma URL construída dessa forma coloca os parâmetros extras na query string. Para um PATCH, isso significa que `client[active]=true` viaja como query param, não como body param. O controller pode ou não receber esses parâmetros dependendo da configuração de strong parameters. Embora Rails mescle query string e body params por padrão, passar dados de estado via query string em requests modificadores é uma má prática que pode causar bugs sutis em logging, caching ou proxies.

**Fix:**
```erb
<%= button_to "Reativar cliente", admin_client_path(client),
      method: :patch,
      params: { client: { active: true } },
      class: "..." %>
```

---

## Info

### IN-01: `content_for(:title)` não é definido em nenhuma view — browser tab sempre mostra "Ilha Criativa"

**File:** `app/views/layouts/admin.html.erb:4`
**Issue:** O layout usa `content_for(:title)` para o `<title>` da aba do browser, mas todas as views de clientes definem apenas `content_for(:page_title)`. O resultado é que a aba do browser sempre exibe "Ilha Criativa" independente da página, prejudicando usabilidade (múltiplas abas indistinguíveis) e SEO (se aplicável).

**Fix:** Sincronizar os dois valores no layout, ou fazer as views definirem ambos:
```erb
<%# Em admin.html.erb %>
<title><%= content_for(:page_title) || content_for(:title) || "Ilha Criativa" %></title>
```

---

### IN-02: Ausência de testes para `rotate_token` e para a ação de desativação

**File:** `test/controllers/admin/clients_controller_test.rb`
**Issue:** O arquivo de testes cobre apenas `create` e `update`. Não há testes para:
- `rotate_token` (verifica se o token muda e invalida sessões do cliente)
- Desativação (`update` com `active: false`)
- Reativação (`update` com `active: true`)
- Acesso não autenticado (verify que rotas retornam 302 sem sessão)

Dado que CR-03 e CR-04 são bugs de desativação, a ausência de testes para esse fluxo contribuiu diretamente para as falhas não serem detectadas.

**Fix:** Adicionar ao menos:
```ruby
test "rotate_token altera access_token do cliente" do
  token_antigo = @client.access_token
  post rotate_token_admin_client_path(@client)
  assert_redirected_to admin_client_path(@client)
  assert_not_equal token_antigo, @client.reload.access_token
end

test "update com active false desativa cliente" do
  patch admin_client_path(@client), params: { client: { active: false } }
  assert_redirected_to admin_client_path(@client)
  assert_not @client.reload.active
end
```

---

### IN-03: Dupla declaração de design tokens em `application.css`

**File:** `app/assets/tailwind/application.css:5-74` e `78-122`
**Issue:** Todos os design tokens (cores, tipografia, bordas, sombras) são declarados duas vezes: primeiro no bloco `@theme { }` (Tailwind v4) e depois no bloco `@layer base { :root { } }` (compatibilidade com CSS custom properties nativas). O comentário indica que a duplicação é intencional para "compatibilidade", mas não há documentação de qual cenário exige isso. Se o projeto usa apenas Tailwind v4, o bloco `@layer base` é redundante. Se o projeto precisa das custom properties para uso direto em CSS manual, então a manutenção em dois lugares é um risco de divergência.

**Fix:** Documentar explicitamente o motivo da duplicação, ou — se o bloco `@layer base` for necessário — usar `@theme` apenas e referenciar as variáveis geradas pelo Tailwind v4 diretamente.

---

_Reviewed: 2026-05-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
