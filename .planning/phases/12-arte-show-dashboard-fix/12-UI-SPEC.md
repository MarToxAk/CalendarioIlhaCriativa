---
phase: 12
slug: arte-show-dashboard-fix
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-03
---

# Phase 12 — UI Design Contract
## Arte Show & Dashboard Fix

> Visual and interaction contract para a Fase 12. Gerado por gsd-ui-researcher a partir das
> decisões travadas em 12-CONTEXT.md (D-01 a D-06) — nenhuma decisão nova foi tomada nesta fase.

---

## Escopo da Fase

Duas mudanças de styling puro em dois arquivos:

1. `app/views/admin/artes/show.html.erb` — reorganizar barra de ações e substituir classes placeholder por Tailwind
2. `app/views/admin/dashboard/index.html.erb` — substituir `btn btn-sm` no link "Ver" (linha 57) por Tailwind

Nenhuma nova feature, nenhum novo arquivo, nenhuma mudança de comportamento.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Tailwind v4 CSS-native, sem shadcn) |
| Preset | não aplicável |
| Component library | nenhuma — ERB com utilitários Tailwind inline |
| Icon library | nenhum — sem ícones SVG adicionados nesta fase |
| Font | Inter (declarado em `app/assets/tailwind/application.css` via `--font-sans`) |

**shadcn gate:** Não aplicável — projeto Rails/ERB, não React/Next.js/Vite.

---

## Spacing Scale

Escala 4-point declarada em `app/assets/tailwind/application.css` (`--spacing-*`):

| Token | Value | Uso nesta fase |
|-------|-------|----------------|
| xs | 4px (`gap-1`) | Não usado diretamente nesta fase |
| sm | 8px (`gap-2`, `px-3`) | Padding horizontal de botões outline/destrutivos |
| md | 16px (`px-4`) | Padding horizontal do botão primário verde (Marcar Revisada) |
| lg | 24px (`mb-6`) | Margem inferior da barra de ações no show |
| xl | 32px | Não usado nesta fase |
| 2xl | 48px | Não usado nesta fase |
| 3xl | 64px | Não usado nesta fase |

Exceções: nenhuma.

**Altura dos elementos interativos:**
- Botões de ação (Editar, Excluir, Marcar Revisada): `h-9` = 36px
- Link "Ver" no dashboard: `h-8` = 32px (compacto, dentro de célula de tabela)

---

## Typography

Fonte base: Inter. Definida em `--font-sans` no `@theme`.

| Role | Size | Weight | Line Height | Uso nesta fase |
|------|------|--------|-------------|----------------|
| Label / button | 14px (`text-sm`) | 500 (`font-medium`) | — | Botões Editar e Excluir |
| CTA / button primary | 14px (`text-sm`) | 600 (`font-semibold`) | — | Botão "Marcar como Revisada" |

Máximo de pesos em uso: 2 (medium 500 + semibold 600).

**Nota:** Body text (células de tabela) e o back link "← Artes" não aplicam nenhuma classe `font-*` explícita — herdam o peso padrão do browser/font sem declaração no sistema. Esses elementos não constituem pesos declarados.

---

## Color

Paleta definida em `app/assets/tailwind/application.css`:

| Role | Value | Uso nesta fase |
|------|-------|----------------|
| Dominant (60%) | `#F9FAFB` (`--color-bg`) | Fundo da página admin |
| Secondary (30%) | `#FFFFFF` (`--color-surface`) | Cards existentes no show; bg dos botões outline |
| Accent (10%) | `#0F7949` (`--color-brand-dark`) | Botão "Marcar como Revisada" apenas |
| Destructive | `#EE3537` (`--color-brand-coral`) | Botão "Excluir" apenas |

**Acento reservado para:** botão primário de ação positiva "Marcar como Revisada" — único CTA verde nesta fase.

**Destrutivo reservado para:** botão "Excluir" — único elemento vermelho nesta fase.

**Outros tons usados:**
- `bg-gray-50` / `border-gray-200`: surface dos botões outline e hover states
- `text-slate-600` / `text-slate-700`: texto de botões neutros e back link
- `text-slate-900`: hover do back link
- `hover:bg-[#0a5c37]`: hover escuro do botão verde (tom mais escuro do acento)
- `hover:bg-red-700`: hover escuro do botão destrutivo

---

## Componentes: Estado Atual → Estado Final

### 1. `app/views/admin/artes/show.html.erb` — Barra de ações

**Estado atual (a remover):**
```erb
<div class="mt-4 flex gap-2">
  link_to "Editar"   class: "btn btn-secondary"
  button_to "Excluir" class: "btn btn-danger"
  button_to "Marcar como Revisada" class: "btn btn-secondary"
  link_to "Voltar"   class: "btn"
</div>
```

**Estado final (contrato):**

Estrutura: back link separado no topo + `flex items-center gap-3` com action buttons — idêntico ao padrão de `app/views/admin/clients/show.html.erb`.

```
[← Artes]  [Editar]  [Excluir]  [Marcar como Revisada]
     ↑           ↑         ↑              ↑
  text link   outline   vermelho        verde
  (no topo,  neutro    sólido          sólido
   fora do   h-9 px-3  h-9 px-3        h-9 px-4
   flex)
```

**Back link "← Artes" (D-01, D-02):**
- Elemento: `link_to` com bloco
- Destino: `admin_artes_path`
- Classe: `text-sm text-slate-600 hover:text-slate-900 transition-colors`
- Aria: `aria: { label: "Voltar para lista de artes" }`
- Texto: `&larr; Artes`
- Posição: dentro do `flex items-center gap-3 mb-6` da barra, à esquerda dos action buttons

**Botão "Editar" (D-03):**
- Elemento: `link_to`
- Destino: `edit_admin_arte_path(@arte)`
- Condição: `if @arte.pending? || @arte.revised? || @arte.change_requested?` — preservar
- Classe: `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors`

**Botão "Excluir" (D-04):**
- Elemento: `button_to`
- Método: `:delete` — preservar
- Condição: `if @arte.pending? && @arte.approval_responses.none?` — preservar
- Data: `data: { confirm: "Tem certeza?" }` — preservar
- Classe: `inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors`
- Nota: `button_to` gera um `<form>` wrapper — adicionar `form: { class: "inline" }` para não quebrar o layout flex

**Botão "Marcar como Revisada" (D-05):**
- Elemento: `button_to`
- Método: `:patch` — preservar
- Condição: `if @arte.change_requested?` — preservar
- Form data: `form: { data: { turbo_confirm: "Confirmar: marcar esta arte como revisada?" } }` — preservar
- Classe: `inline-flex items-center h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors`
- Nota: `px-4` (vs `px-3` dos outros) para dar destaque visual ao CTA principal

**Wrapper da barra de ações:**
- Classe: `flex items-center gap-3 mb-6`
- Substitui o atual: `<div class="mt-4 flex gap-2">`

---

### 2. `app/views/admin/dashboard/index.html.erb` — Link "Ver" (D-06)

**Estado atual (linha 57, a substituir):**
```erb
link_to "Ver", admin_arte_path(arte), class: "btn btn-sm"
```

**Estado final:**
```erb
link_to "Ver", admin_arte_path(arte), class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors"
```

- Carry-forward direto de D-02 da Fase 11 (mesmo elemento, contexto diferente — tabela do dashboard vs index de artes)
- Nenhuma outra linha do arquivo é alterada

---

## Copywriting Contract

| Elemento | Copy |
|----------|------|
| Back link | `← Artes` |
| Back link aria-label | `Voltar para lista de artes` |
| Botão Editar | `Editar` |
| Botão Excluir | `Excluir` |
| Confirmação Excluir | `Tem certeza?` (confirm nativo do browser — preservar `data: { confirm: ... }` existente) |
| Botão Marcar como Revisada | `Marcar como Revisada` |
| Confirmação Marcar Revisada | `Confirmar: marcar esta arte como revisada?` (turbo_confirm — preservar existente) |
| Link Ver (dashboard) | `Ver` |

**Estado vazio:** não aplicável a esta fase — nenhum empty state é adicionado. O dashboard já tem seu próprio empty state (`Nenhuma arte encontrada.`) e não é alterado.

**Estado de erro:** não aplicável — nenhum formulário novo nesta fase.

**Ações destrutivas nesta fase:**
- `Excluir`: confirmação via `data: { confirm: "Tem certeza?" }` (confirm nativo) — padrão já existente, preservar sem mudança
- `Marcar como Revisada`: não é destrutiva, mas requer confirmação via `turbo_confirm` — preservar sem mudança

---

## Referência Canônica

| Arquivo | Papel |
|---------|-------|
| `app/views/admin/clients/show.html.erb` | Template de estrutura: `flex items-center gap-3 mb-6` com back link + action buttons. Linha 4–40 define o padrão completo. |
| `app/views/admin/artes/index.html.erb` | Referência do link "Ver" com estilo `h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors` (implementado na Fase 11). |
| `app/assets/tailwind/application.css` | Fonte de todos os tokens de cor, tipografia, espaçamento e `shadow-card`. |

---

## Padrões Estabelecidos Preservados

Nenhuma variação das classes abaixo é permitida — estas são aprovadas nas fases anteriores:

| Padrão | Classes Tailwind |
|--------|-----------------|
| Text link de navegação (back link) | `text-sm text-slate-600 hover:text-slate-900 transition-colors` |
| Botão outline secundário | `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors` |
| Botão destrutivo vermelho | `inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors` |
| Botão primário verde (CTA) | `inline-flex items-center h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors` |
| Link compacto "Ver" (tabela) | `h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors` |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn oficial | nenhum | não aplicável — projeto não usa shadcn |
| terceiros | nenhum | não aplicável |

Nenhum componente de terceiros é introduzido nesta fase. Toda a implementação usa utilitários Tailwind inline.

---

## Rastreabilidade

| Decisão | Fonte | Campo Afetado |
|---------|-------|---------------|
| D-01 | 12-CONTEXT.md | Estrutura da barra de ações no show (back link separado) |
| D-02 | 12-CONTEXT.md | Classes do text link "← Artes" |
| D-03 | 12-CONTEXT.md | Classes do botão Editar |
| D-04 | 12-CONTEXT.md | Classes do botão Excluir |
| D-05 | 12-CONTEXT.md | Classes do botão Marcar como Revisada |
| D-06 | 12-CONTEXT.md + 11-CONTEXT.md D-02 | Classes do link "Ver" no dashboard |
| Paleta de cores | 10-CONTEXT.md + application.css | Todos os valores hexadecimais |
| Padrão canônico | clients/show.html.erb (lido diretamente) | Estrutura flex da barra de ações |

**Decisões pré-preenchidas de upstream:** 6/6 (todas de 12-CONTEXT.md)
**Decisões tomadas nesta sessão:** 0
**Perguntas feitas ao usuário:** 0

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
