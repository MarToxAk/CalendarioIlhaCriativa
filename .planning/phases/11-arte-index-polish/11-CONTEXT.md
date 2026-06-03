# Phase 11: Arte Index Polish - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Estilizar a página de listagem de artes (`app/views/admin/artes/index.html.erb`): substituir `btn btn-primary` e `btn btn-sm` por Tailwind puro, formatar thead/tbody com o padrão visual dos clients, adicionar empty state e cards mobile. Escopo: somente styling de `index.html.erb` (e possivelmente um partial `_arte_row`). Sem novas features, sem mudanças de comportamento.

</domain>

<decisions>
## Implementation Decisions

### Botão "Nova Arte"
- **D-01:** Substituir `class: "btn btn-primary"` por `class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors inline-flex items-center"` — padrão idêntico ao `app/views/admin/clients/index.html.erb` (carry-forward da Fase 10).

### Link "Ver" nas rows
- **D-02:** Substituir `class: "btn btn-sm"` por botão outline pequeno: `class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors"` — discreto, não compete com "Nova Arte".

### Cabeçalhos e rows da tabela
- **D-03:** `<thead>` recebe `class="bg-gray-50 border-b border-gray-200"`.
- **D-04:** Cada `<th>` recebe `scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-left"` — padrão exato dos clients. Coluna de ações (última) recebe `<span class="sr-only">Ações</span>`.
- **D-05:** Cada `<tr>` do tbody recebe `class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0"`.
- **D-06:** Cada `<td>` recebe `class="py-3 px-4 text-sm text-slate-900"`. Status e plataforma usam `.humanize` em vez de `.capitalize` para evitar `Caption_only` (lesson da Fase 10 / WR-02).

### Empty state
- **D-07:** Replicar o padrão do `app/views/admin/clients/index.html.erb`: SVG de ícone + título `"Nenhuma arte cadastrada"` + texto descritivo + botão `"Cadastrar primeira arte"` com link para `new_admin_arte_path`. Wrapper `<% if @artes.empty? %> ... <% else %> ... <% end %>`.

### Mobile
- **D-08:** Adicionar versão mobile com cards: tabela recebe `class="... hidden sm:block"`, cards ficam em `<div class="block sm:hidden space-y-3">`. Cada card é um `link_to admin_arte_path(arte)` com `bg-white rounded-xl border border-gray-200 shadow-card px-4 py-3` mostrando título/cliente, status e data. Padrão idêntico ao clients mobile.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Padrão canônico (obrigatório ler antes de implementar)
- `app/views/admin/clients/index.html.erb` — padrão completo: botão primário, thead, empty state, cards mobile. Replicar estrutura para artes.
- `app/assets/tailwind/application.css` — definição de `shadow-card` e outras utilities custom.

### Requirements
- `.planning/REQUIREMENTS.md` §IDX-01, IDX-02 — requisitos desta fase.

### Referência de padrões estabelecidos (Fase 10)
- `app/views/admin/artes/_form.html.erb` — padrão de classes Tailwind já aplicado; confirmar consistência.
- `.planning/phases/10-arte-form-polish/10-CONTEXT.md` — decisões de styling da Fase 10 (botão verde, focus ring, etc.).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/admin/clients/index.html.erb` — template completo com empty state + tabela + cards mobile. Copiar estrutura e adaptar para artes.
- `shadow-card` em `app/assets/tailwind/application.css` — já definido e funcionando.

### Established Patterns
- Botão primário verde: `h-10 px-4 bg-[#0F7949] ...` — estabelecido na Fase 10, usar exatamente.
- `humanize` > `capitalize` para enum values com underscore (lesson da Fase 10 WR-02 — `platform`, `status`, `media_type`).

### Integration Points
- `@artes` é a collection no controller; o index já tem a tabela mas sem estilo nos th/td.
- A tabela wrapper já tem `bg-white border border-gray-200 rounded-xl shadow-card` — manter o wrapper, reformatar o conteúdo interno.

</code_context>

<specifics>
## Specific Ideas

- Botão "Ver" deve ser outline pequeno (h-8) — não competir visualmente com "Nova Arte" (h-10 verde).
- Cards mobile: mostrar cliente, status e data — campos mais úteis para identificar a arte na listagem.

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 11-Arte Index Polish*
*Context gathered: 2026-06-03*
