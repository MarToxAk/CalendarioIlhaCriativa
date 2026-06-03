---
phase: 11-arte-index-polish
verified: 2026-06-03T18:00:00Z
status: human_needed
score: 7/7 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Abrir /admin/artes no navegador e verificar o layout visual"
    expected: "thead com fundo cinza diferenciado, hover nas linhas, botão Nova Arte verde, link Ver discreto"
    why_human: "Aparência visual, hover interativo e responsividade mobile não são verificáveis via grep"
  - test: "Redimensionar o navegador para viewport < 640px"
    expected: "Tabela some e os cards mobile aparecem com cliente, status badge e data+plataforma"
    why_human: "Comportamento responsivo requer inspeção visual real"
  - test: "Acessar /admin/artes sem nenhuma arte cadastrada"
    expected: "SVG de imagem + h2 'Nenhuma arte cadastrada' + botão verde aparecem no lugar da tabela"
    why_human: "Empty state requer ambiente com banco limpo ou fixture de 0 registros"
  - test: "Verificar que status exibido não contém underscore (ex: 'Change requested', não 'Change_requested')"
    expected: "Todos os status nas badges e na coluna Plataforma dos cards mobile usam linguagem natural"
    why_human: "Requer inspeção visual de dados reais renderizados no browser"
---

# Phase 11: Arte Index Polish — Verification Report

**Phase Goal:** O admin vê a listagem de artes com tabela formatada e botões de ação visíveis
**Verified:** 2026-06-03T18:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| #   | Truth                                                                                    | Status     | Evidence                                                                                      |
|-----|------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------|
| SC1 | A tabela de artes tem cabeçalhos (thead) estilizados com fundo diferenciado e texto legível | VERIFIED | `index.html.erb` linha 29: `<thead class="bg-gray-50 border-b border-gray-200">` com `th` `uppercase tracking-wide text-slate-500` |
| SC2 | Cada linha da tabela tem padding adequado e destaque visual ao passar o mouse (hover)    | VERIFIED   | `_arte_row.html.erb` linha 2: `hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0`; td: `py-3 px-4 text-sm text-slate-900` |
| SC3 | O botão "Nova Arte" tem estilo visível e reconhecível como ação primária                 | VERIFIED   | `index.html.erb` linhas 7 e 20: `bg-[#0F7949] hover:bg-[#0a5c37] ... text-white text-sm font-semibold rounded-lg` |
| SC4 | O link "Ver" em cada linha da tabela é visível e clicável com estilo consistente         | VERIFIED   | `_arte_row.html.erb` linha 8: `h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50` |

**Score ROADMAP SC:** 4/4 verified

### Must-Haves do PLAN (truths adicionais)

| #   | Truth                                                                                         | Status     | Evidence                                                                       |
|-----|-----------------------------------------------------------------------------------------------|------------|--------------------------------------------------------------------------------|
| T1  | O thead da tabela tem fundo diferenciado (bg-gray-50) e texto em uppercase com tracking legível | VERIFIED | `index.html.erb` linha 29 + `th` classe `uppercase tracking-wide text-slate-500` |
| T2  | Cada linha tem hover:bg-gray-50 e padding adequado (py-3 px-4) nos tds                       | VERIFIED   | `_arte_row.html.erb` linhas 2-9                                                |
| T3  | O botão "Nova Arte" é verde (#0F7949) com texto branco                                        | VERIFIED   | `index.html.erb` linha 7: `bg-[#0F7949] ... text-white`                       |
| T4  | O link "Ver" é um botão outline pequeno (h-8, border, rounded-lg) — visível mas discreto      | VERIFIED   | `_arte_row.html.erb` linha 8: `h-8 px-3 border border-gray-200 rounded-lg`    |
| T5  | Quando não há artes, aparece empty state com SVG, título e botão para cadastrar               | VERIFIED   | `index.html.erb` linhas 12-23: `@artes.empty?` condicional com SVG + h2 + p + link_to verde |
| T6  | Em telas mobile (<sm) a tabela é substituída por cards com título/cliente, status e data      | VERIFIED   | `index.html.erb` linha 47: `block sm:hidden space-y-3` com `arte.client.name`, `render "status_badge"`, `arte.scheduled_on.strftime` |
| T7  | Status e plataforma das artes são exibidos com .humanize (sem underscore visível)             | VERIFIED   | `_arte_row.html.erb` linha 5: `arte.platform.humanize`; `_status_badge.html.erb` linha 17: `arte.status.humanize` (fallback); labels hardcoded em PT para os 4 status mapeados |

**Score PLAN truths:** 7/7 verified

---

## Required Artifacts

| Artifact                                          | Expected                                                | Status     | Details                                                                 |
|---------------------------------------------------|---------------------------------------------------------|------------|-------------------------------------------------------------------------|
| `app/views/admin/artes/index.html.erb`            | Listagem com header, empty state, tabela desktop, cards mobile | VERIFIED | Existe, 64 linhas, contém `bg-[#0F7949]`, `hidden sm:block`, `block sm:hidden`, `@artes.empty?`, `render "arte_row"` |
| `app/views/admin/artes/_arte_row.html.erb`        | Linha com hover/border/padding e botão Ver outline      | VERIFIED   | Existe, 10 linhas, contém `hover:bg-gray-50`, `humanize`, sem `.capitalize`, contém `render "status_badge"` |
| `app/views/admin/artes/_status_badge.html.erb`    | Badge colorido por status (pending/approved/change_requested/revised) | VERIFIED | Existe, 22 linhas, contém `inline-flex items-center`, case/when para todos os 4 status |

---

## Key Link Verification

| From                        | To                             | Via                              | Status   | Details                                                              |
|-----------------------------|--------------------------------|----------------------------------|----------|----------------------------------------------------------------------|
| `index.html.erb`            | `_arte_row.html.erb`           | `render "arte_row", arte: arte`  | WIRED    | `index.html.erb` linha 40: `render "arte_row", arte: arte`           |
| `_arte_row.html.erb`        | `_status_badge.html.erb`       | `render "status_badge", arte: arte` | WIRED | `_arte_row.html.erb` linha 6: `render "status_badge", arte: arte`   |
| `index.html.erb` (mobile)   | `_status_badge.html.erb`       | `render "status_badge", arte: arte` | WIRED | `index.html.erb` linha 53: `render "status_badge", arte: arte` (cards mobile) |

---

## Data-Flow Trace (Level 4)

| Artifact                 | Data Variable   | Source                     | Produces Real Data | Status   |
|--------------------------|-----------------|----------------------------|--------------------|----------|
| `index.html.erb`         | `@artes`        | Controller (fase anterior) | Sim — ActiveRecord collection sanitizada pelo controller admin/artes#index | FLOWING |
| `_arte_row.html.erb`     | `arte`          | `@artes.each` no index     | Sim — local passado via render | FLOWING  |
| `_status_badge.html.erb` | `arte.status`   | ActiveRecord enum field    | Sim — valor real do modelo | FLOWING  |

Note: O controller `admin/artes#index` foi criado na Fase 7. Esta fase não toca o controller — a collection `@artes` já estava funcional.

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — fase é styling-only de ERB/Tailwind sem entry points CLI ou API verificáveis sem servidor.

---

## Probe Execution

Step 7c: SKIPPED — nenhuma probe declarada no PLAN e fase não é migration/tooling.

---

## Requirements Coverage

| Requirement | Fase   | Descrição                                                                       | Status    | Evidence                                                       |
|-------------|--------|---------------------------------------------------------------------------------|-----------|----------------------------------------------------------------|
| IDX-01      | Phase 11 | Tabela de artes tem thead com headers estilizados, td com padding e hover nas rows | SATISFIED | `_arte_row.html.erb`: `hover:bg-gray-50`, `py-3 px-4 text-sm text-slate-900`; `index.html.erb`: `thead class="bg-gray-50 border-b border-gray-200"`, `scope="col"`, `uppercase tracking-wide` |
| IDX-02      | Phase 11 | Botão "Nova Arte" e link "Ver" na index têm estilo visível                      | SATISFIED | `index.html.erb`: `bg-[#0F7949]` no botão Nova Arte; `_arte_row.html.erb`: `h-8 px-3 border border-gray-200 rounded-lg` no link Ver |

**Orphaned requirements check:** REQUIREMENTS.md mapeia SHOW-01 e DASH-01 para Phase 12 (Pending). Nenhum requisito adicional mapeado para Phase 11 além de IDX-01 e IDX-02. Sem requisitos órfãos.

---

## Anti-Patterns Found

Scan nos 3 arquivos modificados pela fase (`index.html.erb`, `_arte_row.html.erb`, `_status_badge.html.erb`):

| File                            | Line | Pattern       | Severity | Impact                                                                                      |
|---------------------------------|------|---------------|----------|---------------------------------------------------------------------------------------------|
| Nenhum anti-pattern encontrado  | —    | —             | —        | —                                                                                           |

Verificações realizadas:
- Sem `btn btn-primary`, `btn btn-sm`, `btn-primary` nos 3 arquivos (exit code 1 = nenhuma ocorrência)
- Sem `.capitalize` nos 3 arquivos da fase (exit code 1 = nenhuma ocorrência)
- Sem `TBD`, `FIXME`, `XXX`, `TODO`, `PLACEHOLDER` nos arquivos da fase
- Sem `return null`, `return {}`, `return []` nos arquivos da fase
- Sem props hardcoded vazios

**Nota sobre `.capitalize` em outros arquivos:** `show.html.erb` (linhas 8-9) e `_form.html.erb` (linhas 30, 34) contêm `.capitalize`. Esses arquivos estão **fora do escopo desta fase** — `show.html.erb` é responsabilidade de SHOW-01 (Phase 12) e `_form.html.erb` foi coberto pela Phase 10. Nenhum desses representa blocker para a fase 11.

---

## Human Verification Required

### 1. Layout visual da tabela desktop

**Test:** Abrir `/admin/artes` no navegador admin
**Expected:** thead com fundo cinza diferenciado do tbody, texto em uppercase/discreto; linhas com hover cinza ao passar o mouse; botão "Nova Arte" verde proeminente no canto superior direito; link "Ver" em cada linha como botão outline pequeno
**Why human:** Aparência visual, estado hover interativo e contraste não são verificáveis via grep

### 2. Responsividade mobile (cards)

**Test:** Redimensionar viewport para < 640px (ou usar DevTools mobile emulation)
**Expected:** A tabela some (`hidden sm:block`) e os cards aparecem (`block sm:hidden`) com nome do cliente, badge de status colorido e data + plataforma humanizada
**Why human:** Comportamento responsivo CSS requer inspeção visual real

### 3. Empty state

**Test:** Acessar `/admin/artes` com banco sem artes cadastradas (ou temporariamente renomear `@artes` no controller para `Arte.none`)
**Expected:** SVG de imagem + h2 "Nenhuma arte cadastrada" + parágrafo descritivo + botão verde "+ Cadastrar primeira arte"
**Why human:** Requer estado específico do banco de dados

### 4. Labels de status sem underscore

**Test:** Com artes de status `change_requested` cadastradas, verificar a coluna Status na tabela desktop e os cards mobile
**Expected:** Badge exibe "Alteração pedida" (não "Change_requested" nem "Change requested")
**Why human:** Requer dados reais renderizados no browser para confirmar o mapeamento case/when

---

## Gaps Summary

Nenhum gap técnico identificado. Todos os 7 must-haves do PLAN e todos os 4 Success Criteria do ROADMAP foram verificados com evidência direta no código.

O status `human_needed` reflete que a fase produz UI visual que requer inspeção no browser para confirmar aparência, interatividade e responsividade — não há lacunas de implementação.

---

_Verified: 2026-06-03T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
