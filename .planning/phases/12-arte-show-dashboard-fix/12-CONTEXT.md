# Phase 12: Arte Show & Dashboard Fix - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Substituir as classes placeholder sem CSS (`btn btn-secondary`, `btn btn-danger`, `btn`, `btn btn-sm`) por classes Tailwind concretas em dois arquivos: `app/views/admin/artes/show.html.erb` e `app/views/admin/dashboard/index.html.erb`.

Escopo exato: somente styling dos botões/links de ação nesses dois arquivos. Sem novas features, sem mudanças de comportamento, sem outros arquivos.

</domain>

<decisions>
## Implementation Decisions

### Layout da barra de ações no show

- **D-01:** Separar "Voltar" como text link no topo da página, fora do `flex gap-2` dos action buttons — padrão idêntico ao `app/views/admin/clients/show.html.erb`. Estrutura resultante: text link `← Artes` no topo, seguido de um `flex gap-2` com Editar + Excluir + Marcar Revisada.
- **D-02:** Text link "Voltar": `← Artes` apontando para `admin_artes_path` com `class: "text-sm text-slate-600 hover:text-slate-900 transition-colors"` — exatamente o padrão do `clients/show.html.erb`.

### Botões de ação no show

- **D-03:** Botão **Editar**: outline neutro secundário — `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors`.
- **D-04:** Botão **Excluir**: vermelho sólido destrutivo — `inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors` — padrão idêntico ao "Desativar cliente" em `clients/show.html.erb`.
- **D-05:** Botão **Marcar como Revisada**: verde sólido primário — `inline-flex items-center h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors` — sinaliza ação positiva principal (único CTA relevante no estado `change_requested`).

### Link "Ver" no dashboard

- **D-06:** Usar exatamente o mesmo estilo do "Ver" no index (D-02 da Fase 11): `h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors` — consistência total entre index e dashboard.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Padrão canônico de show page (obrigatório ler)
- `app/views/admin/clients/show.html.erb` — padrão de layout: text link "← Clientes" no topo + action buttons inline. Replicar estrutura para artes.

### Arquivos a modificar
- `app/views/admin/artes/show.html.erb` — substituir `btn btn-secondary`, `btn btn-danger`, `btn` por Tailwind. Mover Voltar para text link separado.
- `app/views/admin/dashboard/index.html.erb` — substituir `btn btn-sm` do link "Ver" por classes Tailwind (linha 57).

### Requirements
- `.planning/REQUIREMENTS.md` §SHOW-01, DASH-01 — requisitos desta fase.

### Contexto de decisões anteriores
- `.planning/phases/11-arte-index-polish/11-CONTEXT.md` — D-02: estilo do link "Ver" na index (carry-forward direto para o dashboard).
- `.planning/phases/10-arte-form-polish/10-CONTEXT.md` — padrões de cor verde `#0F7949`, outline neutro e botão vermelho.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/admin/clients/show.html.erb` — template de referência: text link no topo + `flex items-center gap-3` com action buttons. Copiar estrutura e adaptar textos/paths para artes.
- Classes de botão já testadas e aprovadas nas fases 10 e 11 — usar sem variações.

### Established Patterns
- Text link de navegação: `text-sm text-slate-600 hover:text-slate-900 transition-colors` — link de voltar em show pages.
- Botão outline secondary: `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors`.
- Botão destrutivo vermelho: `inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors`.
- Botão primário verde: `bg-[#0F7949] hover:bg-[#0a5c37] text-white` — acento do sistema.
- Link compacto (Ver): `h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors`.

### Integration Points
- Os `button_to` de Excluir e Marcar Revisada têm `method:` e `data:` — preservar esses atributos, só substituir `class:`.
- O `link_to "Editar"` e o `link_to "Voltar"` preservam seus paths; só muda o `class:` e a posição estrutural do Voltar.
- `app/views/admin/dashboard/index.html.erb` linha 57: `link_to "Ver", admin_arte_path(arte), class: "btn btn-sm"` — substituição direta.

</code_context>

<specifics>
## Specific Ideas

- Botão "Excluir": usar `#EE3537` (exato do clients/show) para manter paridade visual com "Desativar cliente".
- Botão "Marcar como Revisada": usar `h-9 px-4` (um pouco mais largo que Editar/Excluir `px-3`) para dar destaque visual ao CTA principal no estado `change_requested`.
- Text link "← Artes" deve ter `aria: { label: "Voltar para lista de artes" }` se quiser paridade com o clients/show (que tem aria-label).

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 12-arte-show-dashboard-fix*
*Context gathered: 2026-06-03*
