# Phase 12: Arte Show & Dashboard Fix - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| Arquivo a modificar | Role | Data Flow | Analog mais próximo | Qualidade |
|---------------------|------|-----------|---------------------|-----------|
| `app/views/admin/artes/show.html.erb` | view (show page) | request-response | `app/views/admin/clients/show.html.erb` | exact |
| `app/views/admin/dashboard/index.html.erb` | view (index/table) | request-response | `app/views/admin/artes/index.html.erb` (fase 11, link "Ver") | role-match |

---

## Pattern Assignments

### `app/views/admin/artes/show.html.erb` (view, request-response)

**Analog:** `app/views/admin/clients/show.html.erb`

**Estado atual do arquivo** (linhas 16-27 — trecho a ser substituído):
```erb
  <div class="mt-4 flex gap-2">
    <%= link_to "Editar", edit_admin_arte_path(@arte), class: "btn btn-secondary" if @arte.pending? || @arte.revised? || @arte.change_requested? %>
    <%= button_to "Excluir", admin_arte_path(@arte), method: :delete, data: { confirm: "Tem certeza?" }, class: "btn btn-danger" if @arte.pending? && @arte.approval_responses.none? %>
    <% if @arte.change_requested? %>
      <%= button_to "Marcar como Revisada",
                    mark_revised_admin_arte_path(@arte),
                    method: :patch,
                    class: "btn btn-secondary",
                    form: { data: { turbo_confirm: "Confirmar: marcar esta arte como revisada?" } } %>
    <% end %>
    <%= link_to "Voltar", admin_artes_path, class: "btn" %>
  </div>
```

**Padrão canônico — text link "Voltar"** (`app/views/admin/clients/show.html.erb`, linhas 4-9):
```erb
<div class="flex items-center gap-3 mb-6">
  <%= link_to admin_clients_path,
        aria: { label: "Voltar para lista de clientes" },
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors" do %>
    &larr; Clientes
  <% end %>
```
Adaptar para artes: `admin_artes_path`, aria-label `"Voltar para lista de artes"`, texto `&larr; Artes`.

**Padrão canônico — botão Editar (outline secondary)** (`clients/show.html.erb`, linha 11-12):
```erb
  <%= link_to "Editar cliente", edit_admin_client_path(@client),
        class: "inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors" %>
```
Adaptar: texto `"Editar"`, path `edit_admin_arte_path(@arte)`, condicional `if @arte.pending? || @arte.revised? || @arte.change_requested?`.

**Padrão canônico — botão destrutivo vermelho** (`clients/show.html.erb`, linhas 17-21):
```erb
      <button type="button"
              data-action="click->modal#open"
              class="inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors">
        Desativar cliente
      </button>
```
Para Excluir arte, usar `button_to` (não abre modal — usa `data: { turbo_confirm: }` já existente). Manter `method: :delete` e `data: { turbo_confirm: "Tem certeza?" }`. Substituir apenas `class:`:
```erb
    <%= button_to "Excluir", admin_arte_path(@arte),
          method: :delete,
          data: { turbo_confirm: "Tem certeza?" },
          class: "inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors",
          if @arte.pending? && @arte.approval_responses.none? %>
```

**Padrão — botão primário verde (Marcar como Revisada)** (baseado em `artes/show.html.erb` linha 40, já aprovado na fase 10):
```erb
      class: "h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer"
```
Acrescentar `inline-flex items-center` para consistência com os demais botões. `px-4` (mais largo que `px-3` dos outros) para destacar o CTA principal. Preservar `method: :patch` e `form: { data: { turbo_confirm: } }`.

**Estrutura resultante da barra de ações** (copiar diretamente de `clients/show.html.erb` linhas 4-9, adaptada):
```erb
<%# ===== BARRA DE AÇÕES ===== %>
<div class="flex items-center gap-3 mb-6">
  <%= link_to admin_artes_path,
        aria: { label: "Voltar para lista de artes" },
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors" do %>
    &larr; Artes
  <% end %>

  <%= link_to "Editar", edit_admin_arte_path(@arte),
        class: "inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors" if @arte.pending? || @arte.revised? || @arte.change_requested? %>

  <%= button_to "Excluir", admin_arte_path(@arte),
        method: :delete,
        data: { turbo_confirm: "Tem certeza?" },
        class: "inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors" if @arte.pending? && @arte.approval_responses.none? %>

  <% if @arte.change_requested? %>
    <%= button_to "Marcar como Revisada",
                  mark_revised_admin_arte_path(@arte),
                  method: :patch,
                  class: "inline-flex items-center h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors",
                  form: { data: { turbo_confirm: "Confirmar: marcar esta arte como revisada?" } } %>
  <% end %>
</div>
```
Nota: o `<div class="mt-4 flex gap-2">` original (linha 16 do arquivo atual) é removido; o bloco acima o substitui na íntegra. O `<div class="bg-white rounded-xl ...">` externo (linha 4 do arquivo atual) é mantido.

---

### `app/views/admin/dashboard/index.html.erb` (view, request-response)

**Analog:** padrão do link "Ver" aprovado na fase 11 (carry-forward direto).

**Linha atual a substituir** (`dashboard/index.html.erb`, linha 57):
```erb
                  <%= link_to "Ver", admin_arte_path(arte), class: "btn btn-sm" %>
```

**Padrão a aplicar — link compacto "Ver"** (D-06, carry-forward da fase 11):
```erb
                  <%= link_to "Ver", admin_arte_path(arte),
                        class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors" %>
```
Substituição direta: apenas o atributo `class:`. Path, método e posição estrutural permanecem iguais.

---

## Shared Patterns

### Text link de navegação (Voltar)
**Fonte:** `app/views/admin/clients/show.html.erb`, linhas 5-9
**Aplicar em:** `artes/show.html.erb`
```erb
class: "text-sm text-slate-600 hover:text-slate-900 transition-colors"
```
Sempre dentro de um `link_to` com bloco, com `aria: { label: "Voltar para lista de [recurso]" }`.

### Botão outline secondary (Editar)
**Fonte:** `app/views/admin/clients/show.html.erb`, linha 12
**Aplicar em:** `artes/show.html.erb` (botão Editar)
```
inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors
```

### Botão destrutivo vermelho (Excluir)
**Fonte:** `app/views/admin/clients/show.html.erb`, linhas 19-21
**Aplicar em:** `artes/show.html.erb` (button_to Excluir)
```
inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors
```

### Botão primário verde (CTA principal)
**Fonte:** `app/views/admin/artes/show.html.erb` linha 40 (já existente no arquivo, abaixo da barra de ações)
**Aplicar em:** `artes/show.html.erb` (button_to Marcar como Revisada)
```
inline-flex items-center h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors
```
`px-4` (não `px-3`) para dar destaque visual ao único CTA principal.

### Link compacto "Ver" em tabela
**Fonte:** decisão D-06 / fase 11 carry-forward
**Aplicar em:** `dashboard/index.html.erb` linha 57
```
h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors
```

### Container da barra de ações
**Fonte:** `app/views/admin/clients/show.html.erb`, linha 4
**Aplicar em:** `artes/show.html.erb` (substituir `<div class="mt-4 flex gap-2">`)
```erb
<div class="flex items-center gap-3 mb-6">
```

---

## No Analog Found

Nenhum arquivo desta fase ficou sem analog. Ambos têm correspondência exata no repositório.

---

## Metadata

**Escopo de busca:** `app/views/admin/`
**Arquivos lidos:** `clients/show.html.erb`, `artes/show.html.erb`, `dashboard/index.html.erb`
**Data de extração:** 2026-06-03
