# Phase 10: Arte Form Polish - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Substituir as classes placeholder sem CSS (`form-input`, `btn`, `btn-primary`) por Tailwind puro em todos os campos do formulário de artes (`_form.html.erb`), e adicionar card container + back link nas páginas `new.html.erb` e `edit.html.erb` seguindo o padrão estabelecido nas páginas de clients.

**Escopo exato:** `app/views/admin/artes/_form.html.erb`, `new.html.erb`, `edit.html.erb`. Sem novas features — styling apenas.

**Fora do escopo desta fase:** Arte index, arte show, dashboard, portal do cliente, notificações, exportação de relatórios.

</domain>

<decisions>
## Implementation Decisions

### Card wrapper (new.html.erb e edit.html.erb)

- **D-01:** Usar `max-w-2xl` como largura máxima do card. O form de artes tem ~10 campos — significativamente mais que o form de clients (`max-w-lg`). O respiro extra justifica quebrar a paridade de largura.
- **D-02:** Replicar o padrão exato de `app/views/admin/clients/new.html.erb` para `new.html.erb`: back link (`← Voltar para Artes → admin_artes_path`) + card `bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl`.
- **D-03:** Replicar o padrão exato de `app/views/admin/clients/edit.html.erb` para `edit.html.erb`: back link mostrando o nome da arte (`← Voltar para @arte.title`) apontando para `admin_arte_path(@arte)` + card `bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl`.

### Campos de texto, textarea, date, select

- **D-04:** Substituir todas as ocorrências de `class: "form-input w-full"` por classes Tailwind diretas, copiando o padrão do form de clients: `block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900 bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400`.
- **D-05:** `textarea` (legenda) usa as mesmas classes mas sem `h-11` — usar `min-h-[80px] resize-y` para dar altura inicial e permitir expansão.
- **D-06:** Labels seguem o padrão de clients: `block text-sm font-medium text-slate-900 mb-1.5`.

### Botões (btn, btn-primary)

- **D-07:** Botão de submit (`btn btn-primary`): verde sólido — `inline-flex items-center px-4 py-2 bg-[#0F7949] text-white text-sm font-semibold rounded-lg hover:bg-[#0d6840] transition-colors`.
- **D-08:** Botão Cancelar (`btn`): neutro — `inline-flex items-center px-4 py-2 border border-gray-300 text-slate-700 text-sm font-semibold rounded-lg hover:bg-gray-50 transition-colors`.

### Radio buttons de Tipo de mídia

- **D-09:** Estilo pill/box interativo: cada opção (Upload / Link externo) vira um `<label>` com visual de pill — `cursor-pointer flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium transition-colors`.
- **D-10:** Input radio escondido com `sr-only` dentro de cada label — acessível via teclado mas invisível. O pill inteiro é a área de clique.
- **D-11:** Estado ativo gerenciado via Stimulus controller (`media_type_toggle_controller.js`): estender `selectUpload` e `selectLink` para adicionar/remover classes de destaque (`border-[#0F7949] bg-green-50 text-[#0F7949]`) nos labels dos pills. Adicionar targets `uploadLabel` e `linkLabel` no controller.
- **D-12:** Estado inicial do pill ativo determinado pela lógica SSR existente (já correta no form — `checked: arte.media_file.attached? || arte.external_url.blank?`). O controller chama `toggleFields()` no `connect()`, então a mesma lógica deve inicializar o estilo dos pills também.

### File input

- **D-13:** Usar Tailwind pseudo-elemento `file:` direto no `f.file_field`: classes no input wrapper + classes `file:` para estilizar o botão nativo do browser. Exemplo: `block w-full text-sm text-slate-900 border border-gray-200 rounded-lg cursor-pointer bg-white file:mr-4 file:py-2 file:px-4 file:border-0 file:text-sm file:font-semibold file:bg-green-50 file:text-green-700 hover:file:bg-green-100`.
- **D-14:** Sem label customizado nem JS extra para o file input — solução nativa com `file:` mantém zero complexidade adicional.

### Claude's Discretion

- Largura do card: Claude escolheu `max-w-2xl` (usuário deixou a critério). Preferir respiro sobre paridade com clients.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Formulário de artes (arquivos a modificar)

- `app/views/admin/artes/_form.html.erb` — **ARQUIVO CENTRAL**: substituir `form-input`/`btn`/`btn-primary` por Tailwind puro. Estilizar todos os inputs, textarea, date, select, radio pills e file input.
- `app/views/admin/artes/new.html.erb` — adicionar back link + card wrapper (atualmente só renderiza o form sem container).
- `app/views/admin/artes/edit.html.erb` — idem, back link com `@arte.title` + card wrapper.

### Padrão de referência (copiar estrutura)

- `app/views/admin/clients/new.html.erb` — **PADRÃO CANÔNICO** para back link e card container. Copiar estrutura exata, adaptar paths e textos para artes.
- `app/views/admin/clients/edit.html.erb` — idem para edit.
- `app/views/admin/clients/_form.html.erb` — **PADRÃO CANÔNICO** para classes dos inputs. Copiar as classes Tailwind dos `text_field`, `password_field`, `label` para usar no form de artes.

### Stimulus controller (estender para pills)

- `app/javascript/controllers/media_type_toggle_controller.js` — controller existente que gerencia visibilidade dos campos upload/link. Precisa ser extendido com targets `uploadLabel`/`linkLabel` e lógica de toggle de classes CSS nos pills.

### Requisitos

- `.planning/REQUIREMENTS.md` — FORM-01, FORM-02, FORM-03, PAGE-01, PAGE-02.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/admin/clients/_form.html.erb` — classes Tailwind dos inputs já definidas e testadas (`h-11 px-3 border border-gray-200 rounded-lg text-sm ... focus:border-[#0F7949]`). Copiar direto.
- `app/javascript/controllers/media_type_toggle_controller.js` — targets `uploadField`, `linkField`, `uploadRadio`, `linkRadio` + métodos `selectUpload`, `selectLink`, `toggleFields`. Adicionar `uploadLabel`, `linkLabel` como novos targets e estender os métodos existentes.
- CSS variable `--shadow-card` definida em `app/assets/tailwind/application.css` — disponível como utilidade Tailwind (`shadow-card`) para o card wrapper.

### Established Patterns

- Tailwind v4 CSS-native com acento verde `#0F7949` — não criar classes customizadas, usar utilitários inline.
- `shadow-card` disponível como classe Tailwind (CSS variable definida).
- Labels com `block text-sm font-medium text-slate-900 mb-1.5`.
- Inputs com `h-11` para altura uniforme (exceto textarea).
- Focus: `focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10`.

### Integration Points

- `app/views/admin/artes/_form.html.erb` — `data: { controller: "media-type-toggle" }` já no `form_with`. Não alterar o controller binding, só estender o JS controller.
- Os targets Stimulus existentes nos radio buttons (`data: { action: "media-type-toggle#selectUpload", media_type_toggle_target: "uploadRadio" }`) permanecem. Adicionar `media_type_toggle_target: "uploadLabel"` nos labels dos pills.

</code_context>

<specifics>
## Specific Ideas

- Pill de radio ativo: `border-[#0F7949] bg-green-50 text-[#0F7949]` — mesmas cores do focus ring dos inputs para consistência.
- Pill inativo: `border-gray-200 text-slate-700` — neutro.
- File input estilizado com `file:bg-green-50 file:text-green-700 hover:file:bg-green-100` — verde claro consistente com o acento do sistema.
- Back link no edit: `← Voltar para <%= @arte.title %>` (igual ao padrão de clients que usa `@client.name`).

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 10-arte-form-polish*
*Context gathered: 2026-06-03*
