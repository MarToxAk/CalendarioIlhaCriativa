---
phase: 28-divulga-o-agendar-sem-enviar
plan: 03
subsystem: ui
tags: [rails, activestorage, stimulus, erb, divulgacao, pt-br, preview, estimate]

requires:
  - phase: 28-divulga-o-agendar-sem-enviar
    provides: "divulgacoes/divulgacao_grupos schema, Divulgacao/DivulgacaoGrupo models, Admin::DivulgacoesController#create happy path, criacao-time validations (arte_deve_estar_aprovada, arte_nao_usa_link_externo, arquivo_dentro_do_teto_whatsapp, arte_e_grupos_do_mesmo_cliente, scheduled_for_no_futuro), Admin::DivulgacoesHelper#divulgacao_datetime_label, new.html.erb com _picker.html.erb reutilizado"
provides:
  - "_preview.html.erb (locals: arte:) — prévia real da mídia (image_tag/video via rails_storage_proxy_path, sem presign) + legenda VERBATIM auto-escapada pelo ERB (DIVU-06); branch caption_only sem media_file"
  - "Divulgacao::SEND_DELAY_MIN / SEND_DELAY_MAX = Integer(ENV.fetch('WHATSAPP_SEND_DELAY_MIN_SECONDS'/'..._MAX_SECONDS', '25'/'45')) — ponto único de leitura do contrato de delay entre grupos que a fase 29 (ENVIO-02) possui"
  - "Admin::DivulgacoesHelper#divulgacao_duration_estimate(n, min:, max:) — '—' para n=0, valor único quando lo==hi, faixa '≈ lo–hi min para n grupos' caso contrário (DIVU-07); fonte da verdade / fallback sem-JS"
  - "divulgacao_preview_controller.js — toggle sem-rede entre painéis _preview ocultos (um por arte aprovada), acionado pela troca do select de arte"
  - "divulgacao_estimate_controller.js — espelha divulgacao_duration_estimate no cliente, recomputa a cada mudança de checkbox de grupo"
  - "picker_controller.js — liga os marcadores select-all/contador que a fase 27 shipou inertes no _picker.html.erb (sem rede, propaga um change sintético para o estimate recomputar)"
  - "new.html.erb agora renderiza: select de arte + N painéis _preview ocultos + _picker (field_name vivo) com data-controller=\"picker\" + card de estimativa com data-controller=\"divulgacao-estimate\""
affects: [29-motor-de-envio, 30-acompanhamento-ao-vivo-hardening]

actuals:
  tokens: 9500
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Prévia de mídia sem JS: partial ERB por arte, um painel oculto por opção, alternado por um controller Stimulus puramente de exibição (nenhuma rede, nenhum fetch)"
    - "Fonte da verdade duplicada e sincronizada deliberadamente: o helper server-side é idêntico em fórmula ao controller Stimulus client-side — nenhum dos dois lê o outro, mas ambos leem os mesmos data-*-value injetados pelo servidor a partir de Divulgacao::SEND_DELAY_MIN/MAX"
    - "Reativação de markup inerte: fase 27 shipou data-picker-select-all/data-picker-counter sem controller; fase 28 liga um Stimulus controller novo sobre o markup existente sem tocar o partial _picker.html.erb"
    - "Encadeamento de eventos Stimulus: o select-all despacha um evento change sintético no wrapper (não em si mesmo) para o controller de estimativa, que está mais acima na cadeia data-action, recomputar sem duplo-toggle"

key-files:
  created:
    - app/views/admin/divulgacoes/_preview.html.erb
    - app/javascript/controllers/divulgacao_preview_controller.js
    - app/javascript/controllers/divulgacao_estimate_controller.js
    - app/javascript/controllers/picker_controller.js
  modified:
    - app/models/divulgacao.rb (SEND_DELAY_MIN/MAX constants)
    - app/helpers/admin/divulgacoes_helper.rb (divulgacao_duration_estimate)
    - app/views/admin/divulgacoes/new.html.erb (wiring: preview panels, picker controller, estimate card)
    - test/controllers/admin/divulgacoes_controller_test.rb (end-to-end #new wiring assertions)
    - test/helpers/admin/divulgacoes_helper_test.rb (estimate zero-state + lo==hi collapse + range cases)

key-decisions:
  - "Legenda impressa via `<%= arte.caption %>` puro — ERB auto-escapa por padrão; nenhum `raw`/`html_safe`/`sanitize` em nenhum ponto do partial (DIVU-06 exige verbatim, não confiança cega — um `<script>` na legenda renderiza como texto inerte)."
  - "Vídeo sem poster/variant — `<video controls playsinline preload=\"none\">` cru, evitando dependência de `ffmpeg`/`mini_magick` para gerar thumbnail de vídeo nesta fase (decisão já travada no 28-UI-SPEC)."
  - "`WHATSAPP_SEND_DELAY_MIN_SECONDS`/`_MAX_SECONDS` como nomes de env var, fallback 25/45 — consistente com a resolução de Open Question do 28-CONTEXT.md. A fase 29 (ENVIO-02) é dona da leitura canônica; a fase 28 só consome via `Divulgacao::SEND_DELAY_MIN/MAX`."
  - "Estimativa client-side (Stimulus) e server-side (helper) implementam a MESMA fórmula independentemente, ambas alimentadas pelos mesmos data-*-value — nenhuma faz fetch da outra. Garante que o fallback sem-JS (render inicial do helper) e o recompute ao vivo nunca divergem em lógica, só em timing."

patterns-established:
  - "Painel de prévia por opção: ao invés de re-renderizar via fetch quando o select muda, o servidor pré-renderiza TODOS os painéis (um por arte aprovada) ocultos, e o JS só alterna `hidden` — zero requisições de rede para trocar a prévia."

requirements-completed: [DIVU-05, DIVU-06, DIVU-07]

coverage:
  - id: D1
    description: "Preview mostra a mídia real (imagem ou vídeo) da arte selecionada, sem chamada de rede"
    requirement: DIVU-06
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#end-to-end #new wiring — one hidden preview pane per approved arte"
        status: pass
    human_judgment: false
  - id: D2
    description: "Legenda aparece verbatim na prévia, sem transformação, e é auto-escapada pelo ERB (sem raw/html_safe)"
    requirement: DIVU-06
    verification:
      - kind: other
        ref: "code inspection: app/views/admin/divulgacoes/_preview.html.erb — plain `<%= arte.caption %>`, no raw/html_safe/sanitize call in the file"
        status: pass
    human_judgment: true
    rationale: "A ausência de raw/html_safe foi confirmada por inspeção de código nesta sessão, mas não há um teste automatizado dedicado que injete um payload `<script>` na caption e assert o output escapado — recomendado como follow-up, não bloqueante para esta fase."
  - id: D3
    description: "Arte caption_only (sem media_file) mostra '(sem mídia — mensagem de texto)' na prévia, sem erro"
    requirement: DIVU-06
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#end-to-end #new wiring (2-arte fixture inclui uma caption_only)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Estimativa de duração mostra '—' quando zero grupos selecionados, valor único quando lo==hi, faixa caso contrário"
    requirement: DIVU-07
    verification:
      - kind: unit
        ref: "test/helpers/admin/divulgacoes_helper_test.rb#divulgacao_duration_estimate zero-state / lo==hi collapse / range cases"
        status: pass
    human_judgment: false
  - id: D5
    description: "Delay min/max lidos de WHATSAPP_SEND_DELAY_MIN_SECONDS/_MAX_SECONDS com fallback 25/45"
    requirement: DIVU-07
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb (SEND_DELAY_MIN/MAX default values, exercised via helper tests)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Estimativa recomputa ao vivo quando a seleção de grupos muda (picker + select-all), sem rede"
    requirement: DIVU-07
    verification:
      - kind: other
        ref: "code inspection: divulgacao_estimate_controller.js + picker_controller.js data-action wiring in new.html.erb"
        status: pass
    human_judgment: true
    rationale: "Comportamento client-side de Stimulus (recompute ao clicar checkbox) não tem um teste de sistema/JS headless nesta fase — verificado por inspeção da cadeia data-action e pela lógica espelhada ao helper server-side testado (D4). Recomendado um teste de sistema (Capybara + JS driver) como follow-up."
  - id: D7
    description: "Todo datetime renderizado na área de preview/estimate carrega o sufixo explícito (BRT)"
    requirement: DIVU-05
    verification:
      - kind: unit
        ref: "test/helpers/admin/divulgacoes_helper_test.rb#divulgacao_datetime_label (herdado do plano 28-02, reafirmado aqui — nenhuma nova superfície de datetime introduzida no plano 03)"
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-08-30
status: complete
---

# Phase 28 Plan 03: Preview + Estimate Summary

**Prévia sem-JS da mídia/legenda real (auto-escapada) + estimativa de duração ao vivo (helper server-side + espelho Stimulus client-side) para o form de Divulgação**

## Performance

- **Duration:** ~35min
- **Tasks:** 3
- **Files modified:** 9 (4 criados, 5 modificados)

## Accomplishments
- `_preview.html.erb` renderiza a mídia real da arte (imagem via `image_tag`, vídeo via `<video controls playsinline preload="none">`), ambos pela rota proxy do ActiveStorage — sem presign, sem link que expira enquanto o admin preenche o formulário.
- Legenda impressa verbatim, auto-escapada pelo ERB padrão — nenhum bypass de escape em nenhum ponto do partial.
- `Divulgacao::SEND_DELAY_MIN`/`SEND_DELAY_MAX` estabelecem o ponto único de leitura do contrato de delay que a fase 29 (ENVIO-02) vai possuir; `divulgacao_duration_estimate` implementa a fórmula (zero-state, colapso lo==hi, faixa) tanto server-side quanto — espelhada — no Stimulus.
- `picker_controller.js` liga o select-all/contador que a fase 27 deixou inertes no `_picker.html.erb`, sem tocar o partial em si.

## Task Commits

Each task was committed atomically:

1. **Task 1: `_preview.html.erb` + `divulgacao_preview_controller.js` + wire into the form** - `586e63c` (feat)
2. **Task 2: duration estimate helper + constants + estimate/picker Stimulus controllers** - `d382236` (feat, tdd)
3. **Task 3: end-to-end form wiring check — preview toggles and estimate recomputes together** - `b0bdd06` (test)

_Note: this SUMMARY was authored and committed separately from the task commits above — the executor agent that ran tasks 1-3 hit a session rate-limit immediately after the final task commit, before it could write and commit this file. The orchestrator verified all 3 commits (via `git log`/`git diff --stat` against the plan's base SHA), re-ran the full plan test scope (52/52 green), read the implementation files to confirm the security/behavior claims below, and then authored this SUMMARY.md itself before merging the worktree. No code was written or modified by the orchestrator — only this documentation file._

## Files Created/Modified
- `app/views/admin/divulgacoes/_preview.html.erb` - Prévia real (imagem/vídeo/caption_only) + legenda verbatim auto-escapada
- `app/javascript/controllers/divulgacao_preview_controller.js` - Toggle sem-rede entre painéis de prévia
- `app/javascript/controllers/divulgacao_estimate_controller.js` - Recompute client-side da estimativa
- `app/javascript/controllers/picker_controller.js` - Liga select-all/contador do picker da fase 27
- `app/models/divulgacao.rb` - `SEND_DELAY_MIN`/`SEND_DELAY_MAX` constantes
- `app/helpers/admin/divulgacoes_helper.rb` - `divulgacao_duration_estimate`
- `app/views/admin/divulgacoes/new.html.erb` - Wiring dos 3 controllers + painéis de prévia + card de estimativa
- `test/controllers/admin/divulgacoes_controller_test.rb` - Cobertura de wiring do `#new` (2 artes, 3 grupos)
- `test/helpers/admin/divulgacoes_helper_test.rb` - Casos de zero-state, colapso lo==hi, faixa

## Decisions Made
- Legenda via `<%= arte.caption %>` puro (auto-escape do ERB) — nenhum `raw`/`html_safe`/`sanitize`, confirmado por inspeção de código.
- Vídeo sem poster/variant — evita dependência de geração de thumbnail nesta fase (decisão já travada no 28-UI-SPEC).
- Nomes de env var `WHATSAPP_SEND_DELAY_MIN_SECONDS`/`_MAX_SECONDS`, fallback `25`/`45` — consistente com a resolução de Open Question do 28-CONTEXT.md.
- Estimativa client-side e server-side implementam a mesma fórmula independentemente (nenhuma faz fetch da outra) — ambas lêem os mesmos `data-*-value` injetados a partir da constante do model.

## Deviations from Plan

None - plan executed exactly as written pelos 3 commits de task. Nenhum desvio documentado pelo executor original nos commits (mensagens de commit não mencionam Rule 1/2/3).

## Issues Encountered
- **Interrupção de sessão (rate limit) pós-execução:** o executor original completou e commitou as 3 tasks com sucesso, mas atingiu o limite de sessão da API antes de escrever/commitar este SUMMARY.md. O orquestrador verificou o trabalho (testes + inspeção de código) e completou a documentação — ver nota em "Task Commits" acima. Nenhum trabalho foi perdido ou refeito.
- Suíte de teste roda via `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test <files>` (workaround de socket unix — `.env` é bloqueado pelo sandbox para agentes). Worktree precisou de um `.bundle/config` gitignored apontando para o `vendor/bundle` do checkout principal (mesmo padrão dos planos 28-01/28-02).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `Divulgacao::SEND_DELAY_MIN`/`SEND_DELAY_MAX` prontos para a fase 29 (ENVIO-02) consumir/estender.
- Plano 28-04 (form states + `#show`/`#cancel` + `clients#show` entry point) pode prosseguir — a área de preview/estimativa está totalmente funcional no `#new`.
- Follow-up não-bloqueante recomendado (fora de escopo desta fase): teste de sistema (Capybara + driver JS) para o comportamento ao vivo do Stimulus, e um teste dedicado de payload `<script>` na legenda para reforçar D2 com uma prova automatizada em vez de só inspeção de código.

---
*Phase: 28-divulga-o-agendar-sem-enviar*
*Completed: 2026-08-30*
