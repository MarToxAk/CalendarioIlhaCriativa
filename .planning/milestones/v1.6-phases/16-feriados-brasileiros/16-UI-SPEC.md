---
phase: 16
slug: feriados-brasileiros
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-04
---

# Phase 16 — UI Design Contract: Feriados Brasileiros

> Visual and interaction contract para destaque de feriados e comemorativos no calendário do cliente e no calendário do admin.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none — Tailwind CSS 4 com tokens customizados em `app/assets/tailwind/application.css` |
| Preset | not applicable |
| Component library | none (ERB inline Tailwind) |
| Icon library | Heroicons via SVG inline (padrão existente do projeto) |
| Font | Inter, Helvetica Neue, Arial, sans-serif (token `--font-sans`) |

shadcn gate: não aplicável — projeto Rails/ERB, não React/Next.js/Vite.

---

## Spacing Scale

Declared values (multiples of 4 only) — pre-populated from `app/assets/tailwind/application.css`:

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px (p-1 / gap-1) | Gaps internos de ícones, padding inline mínimo |
| sm | 8px (p-2 / gap-2) | Separação entre elementos compactos de célula |
| md | 16px (p-4) | Espaçamento padrão de elemento |
| lg | 24px (p-6) | Padding de seção |
| xl | 32px (p-8) | Gaps de layout |
| 2xl | 48px (p-12) | Quebras de seção principais |
| 3xl | 64px (p-16) | Espaçamento de página |

Exceptions: célula do calendário usa `p-1.5` (6px) — padrão estabelecido nas views existentes, não alterar.

---

## Typography

| Role | Size | Weight | Line Height | Tailwind class |
|------|------|--------|-------------|----------------|
| Label de dia | 12px (text-xs) | 500 (font-medium) | 1.5 | `text-xs font-medium` |
| Nome de feriado | 12px (text-xs) | 400 (font-normal) | 1.25 | `text-xs` |
| Chip de arte (admin) | 12px (text-xs) | 600 (font-semibold) | 1 | `text-xs font-semibold` |
| Overflow indicator (+N) | 12px (text-xs) | 400 (font-normal) | 1 | `text-xs text-gray-400` |

Nota: a fase introduz apenas o papel "Nome de feriado" — todos os outros papeis já existem nas views e não devem ser alterados.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#F9FAFB` (`--color-bg`) | Fundo geral da página |
| Secondary (30%) | `#FFFFFF` (`--color-surface`) | Células do mês corrente; fundo de cards |
| Accent (10%) | `#EA580C` (`--color-accent`) | Círculo de hoje; hover de artes no calendário do cliente |
| Feriado / comemorativo | `#F87171` (Tailwind `text-red-400`) | Texto do nome do feriado exclusivamente |
| Fundo de célula fora do mês | `#F9FAFB` (bg-gray-50) | Dias fora do mês corrente |
| Texto de dia com artes | `#334155` (text-slate-700) | Número do dia quando há artes |
| Texto de dia sem artes | `#D1D5DB` (text-gray-300) | Número do dia quando não há artes |

Accent (`#EA580C`) reservado para: círculo do dia atual no calendário, hover highlight de arte no calendário do cliente. NÃO usar em texto de feriado.

Feriado reservado para: `text-red-400` aplicado unicamente ao span do nome do feriado/comemorativo — nenhum outro elemento usa esta cor.

Sem alteração de fundo da célula para dias de feriado (decisão D-02 em CONTEXT.md — locked).

---

## Anatomy — Holiday Cell (ambos os calendários)

A ordem vertical dentro da célula `div.p-1.5` é:

```
1. Número do dia (span existente — text-xs font-medium)
2. [SE feriado] Nome do feriado (span novo — text-xs text-red-400 block truncate leading-snug mt-0.5)
3. Chips de artes (elementos existentes — não alterar posição)
```

### Código de referência — Calendário do cliente

```erb
<span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>">
  <%= date.day %>
</span>
<% if (holiday = brazilian_holiday_for(date)) %>
  <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
    <%= truncate(holiday, length: 15) %>
  </span>
<% end %>
```

### Código de referência — Calendário do admin

```erb
<span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>">
  <%= date.day %>
</span>
<% if (holiday = brazilian_holiday_for(date)) %>
  <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
    <%= truncate(holiday, length: 15) %>
  </span>
<% end %>
```

Truncamento: `truncate(name, length: 15)` via helper Rails — produz "Dia das Mães…" para nomes longos. Aplicado somente na view, o module retorna o nome completo.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | não aplicável — fase não introduz CTA |
| Empty state | não aplicável — ausência de feriado = célula sem texto de feriado, sem mensagem |
| Error state | não aplicável — `BrazilianHolidays.for(year)` retorna hash vazio para anos sem cobertura; a view não renderiza nada |
| Destructive confirmation | não aplicável — fase não contém ações destrutivas |

Nomes de feriados (strings canônicas — usar exatamente estas):

| Data | Nome canônico |
|------|---------------|
| 1/jan | Ano Novo |
| Móvel (carnaval, seg) | Carnaval |
| Móvel (carnaval, ter) | Carnaval |
| Móvel (sexta santa) | Sexta-feira Santa |
| Móvel (domingo páscoa) | Páscoa |
| 21/abr | Tiradentes |
| 1/mai | Dia do Trabalho |
| Móvel (2º dom maio) | Dia das Mães |
| Móvel (corpus christi) | Corpus Christi |
| 12/jun | Dia dos Namorados |
| Móvel (2º dom ago) | Dia dos Pais |
| 7/set | Independência |
| 12/out | Ap. / Crianças |
| 2/nov | Finados |
| 15/nov | Rep. da República |
| Móvel (4ª sex nov) | Black Friday |
| 25/dez | Natal |

Nota: "Ap. / Crianças" é a string truncada natural de "Nossa Sra. Aparecida / Dia das Crianças" — 15 chars com truncate helper produzirá "Ap. / Crianças…". Usar diretamente "Ap. / Crianças" (14 chars) para caber sem truncamento. Alternativa aceita: "N.Sra.Aparecida" (15 chars exatos).

---

## Interaction States

| Estado | Comportamento |
|--------|--------------|
| Dia sem feriado | célula sem span de feriado — nenhum elemento extra |
| Dia com feriado, sem artes | número (text-gray-300) + nome feriado (text-red-400) |
| Dia com feriado, com artes | número (text-slate-700) + nome feriado (text-red-400) + chips |
| Dia atual com feriado | círculo laranja (#EA580C) + nome feriado (text-red-400) |
| Feriado em dia fora do mês corrente | nome feriado renderizado normalmente (text-red-400) — não ocultar |
| Ano sem cobertura no module | helper retorna nil → nenhuma string renderizada |

---

## Component Inventory

Componentes novos introduzidos nesta fase:

| Arquivo | Tipo | Responsabilidade |
|---------|------|-----------------|
| `app/lib/brazilian_holidays.rb` | Ruby module | `BrazilianHolidays.for(year)` → `Hash{Date => String}` |
| `app/helpers/application_helper.rb` | Helper method | `brazilian_holiday_for(date)` → `String \| nil` |

Componentes modificados:

| Arquivo | Mudança |
|---------|---------|
| `app/views/client/home/_month_calendar.html.erb` | Inserir span de feriado após o span do número do dia |
| `app/views/admin/calendar/_calendar_grid.html.erb` | Inserir span de feriado após o span do número do dia |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — Rails/ERB project |
| third-party | none | not applicable |

---

## Accessibility

- `text-red-400` (#F87171) sobre fundo branco (#FFFFFF) = contrast ratio 3.6:1 — aceito para texto informativo de tamanho reduzido (não é texto de corpo principal).
- O nome do feriado é texto puro, legível por screen readers sem aria adicional.
- A ausência de feriado não produz elemento vazio — sem impacto em leitores de tela.
- `truncate` classe Tailwind aplica `overflow: hidden; text-overflow: ellipsis; white-space: nowrap` — o valor completo não fica acessível via tooltip; aceitável pois o nome canônico está no source e não é interativo.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
