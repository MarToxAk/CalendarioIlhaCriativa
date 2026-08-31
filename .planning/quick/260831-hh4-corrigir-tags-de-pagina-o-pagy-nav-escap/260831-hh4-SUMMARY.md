---
status: complete
---

# Corrigir tags de paginação (pagy_nav) escapadas como texto

**Tasks:** 1/1

**Causa raiz:** `Pagy::Frontend#pagy_nav` (gem `pagy` 9.4.0) constrói a string de
navegação como `String` Ruby comum, sem `.html_safe`. `ActionView::OutputBuffer#<<`
(usado por `<%= %>`) escapa qualquer valor não marcado como seguro — por isso
`<%= pagy_nav(pagy) %>` produzia `&lt;nav class="pagy nav"...` visível na tela em
vez de uma navegação real. `app/views/admin/divulgacoes/index.html.erb` já usava
o padrão correto (`<%==`, saída não-escapada do Erubi); os outros dois call-sites
não.

**Fix:** trocado `<%=` por `<%==` em `pagy_nav(pagy)` / `pagy_nav(@pagy)` nos
dois arquivos afetados.

**Verificação:** renderizado o partial `_picker.html.erb` de verdade via
`ApplicationController.render`, com o client 31 (64 grupos reais sincronizados
nesta mesma sessão) — antes do fix o HTML continha `&lt;nav`; depois do fix
contém `<nav class="pagy nav" ...>` cru, exatamente como em `divulgacoes/index.html.erb`.

**Arquivos alterados:**
- `app/views/admin/whatsapp_groups/_picker.html.erb`
- `app/views/admin/approvals/index.html.erb`

**Commit:** `ad33377`

**Escopo não tocado:** `app/views/admin/divulgacoes/index.html.erb` (já estava
correto, não precisou de mudança).
