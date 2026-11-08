---
phase: 33-upload-de-arquivo-pela-api-de-ia
plan: 02
subsystem: docs
tags: [docs, api-ia, multipart, upload, gate-final]

requires:
  - phase: 33-upload-de-arquivo-pela-api-de-ia
    provides: "plano 01: POST /artes multipart, 400 bad_request, 503 storage_unavailable"
provides:
  - "docs/api-ia.md ensina o upload multipart ponta a ponta (servido em GET /api/v1/ai/docs)"
  - "gate final da fase 33: lint, brakeman, suites e escopo do diff verdes"
affects: [verificacao da fase 33, UAT de fim de fase]

actuals:
  tokens: 927
  tasks: 2
  commits: 1

tech-stack:
  added: []
  patterns:
    - "documentacao da API como contrato lido pelo agente de IA, sincronizada com o controller por leitura"

key-files:
  created: []
  modified:
    - docs/api-ia.md

key-decisions:
  - "A documentacao nao cita valor de expiracao da media_url nem limite de body do proxy: ambos sao [ASSUMED] na pesquisa e nao foram verificados"
  - "O limite de body do proxy e o envio real ao S3/MinIO ficam como human-check de fim de fase, nunca como afirmacao verificada"

requirements-completed: []  # o plano declara requirements: [TBD]; nao ha ID real a marcar

coverage:
  - id: D1
    description: "docs/api-ia.md descreve o upload multipart (tipos, 50 MB, curl -F, arquivo+link = 422) sem o aviso obsoleto de upload nao suportado"
    verification:
      - kind: command
        ref: "grep gates da Task 1 (multipart/form-data=4, -F media_file=@=1, 50 MB=3, video/quicktime=2; 'nao e suportado'=0, 'uma arte criada pela API tem'=0, 'devolve 400'=0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Contrato de resposta e erro documentado (201 pending/upload/media_url, 422 media_file, 400 bad_request, 503 storage_unavailable) coincide com o controller do 33-01"
    verification:
      - kind: command
        ref: "storage_unavailable=2 no texto; conferencia por leitura contra app/controllers/api/v1/ai/artes_controller.rb"
        status: pass
    human_judgment: false
  - id: D3
    description: "Teste de sincronia entre rotas e documentacao continua verde"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/docs_controller_test.rb (0 failures, 0 errors, 0 skips)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Gate final: rubocop, brakeman, suites de IA + admin artes + model arte + isolamento, escopo do diff"
    verification:
      - kind: command
        ref: "bin/rubocop (27 arquivos, 0 ofensas); bin/brakeman (0 avisos); 115 runs, 601 assertions, 0 failures, 0 errors, 0 skips; diff de escopo = 3 arquivos esperados"
        status: pass
    human_judgment: false
  - id: D5
    description: "Limite de body do proxy (nginx-proxy-manager) e envio real ao S3/MinIO em producao"
    verification: []
    human_judgment: true
    rationale: "Nao esta no repositorio nem e alcancavel pelo CI; depende de upload real de ~20 MB pela URL publica apos o deploy (human-check abaixo)"

duration: 12min
completed: 2026-11-08
status: complete
commits: 1
plan_head_before: 7a65c85970aa82443e997170b2501d5d7359b36f
plan_head_after: 6ca2d27d597d07b84395a0740d747fb9c0b2b4cd
---

# Phase 33 Plan 02: Documentacao do upload e gate final Summary

**docs/api-ia.md agora ensina o upload multipart do POST /artes (tipos, limite de 50 MB, curl -F, erros 400/422/503, aprovacao pelo cliente) e a fase fecha com lint, brakeman e 115 testes verdes pela receita local, escopo do diff confinado a controller, teste e documentacao.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-11-08
- **Tasks:** 2 (1 com commit de documentacao, 1 so de verificacao)
- **Files modified:** 1 (`docs/api-ia.md`)

## Accomplishments

- Secao 2: o `Content-Type: application/json` ganhou a excecao do `POST /artes` com arquivo (`multipart/form-data`, sem definir o header a mao).
- Secao 3: 400 `bad_request` inclui `media_file` que nao e arquivo; nova linha `503 storage_unavailable` (nada criado, seguro repetir).
- Secao 4: paragrafo antes da lista (sem renumerar) mandando criar a arte com arquivo; ela nasce `pending` e o cliente aprova pelo link, sem atalho para a IA.
- Secao 5.2: bloco do `POST /artes` reescrito com tabela de parametros (`media_file` OU `external_url`), regras do upload, exemplo `curl -F`, resposta 201 (`pending`, `upload`, `media_url` temporaria, nao guardar), erros 422/400/503, aviso do D-03 (`external_url` sozinho aceito, mas nao divulgavel ate um humano subir o arquivo) e aviso de timeout (POST nao idempotente; arte `pending` nao aparece em `GET /artes`).
- Removidos os textos obsoletos ("nao e suportado", "devolve 400", "uma arte criada pela API tem external_url"). Cabecalhos `GET /artes` e `POST /artes` preservados; referencia cruzada da secao 5.1 continua valida.
- Secao 6: limite de 50 MB do arquivo da arte ao lado dos 16 MB da midia de divulgacao (16 a 50 MB aceito no upload, recusado no agendamento) e nota de que 413 sem envelope JSON vem do proxy.

## Task Commits

1. **Task 1: docs/api-ia.md** - `6ca2d27` (docs)
2. **Task 2: gate final** - sem commit proprio (task de verificacao; nenhum arquivo rastreado muda)

## Verification (receita local; o CI e a autoridade, D-12)

- `docs_controller_test.rb`: 0 failures, 0 errors, 0 skips (sincronia de rotas e conteudo).
- Gates grep da Task 1: positivos `multipart/form-data`=4, `-F media_file=@`=1, `storage_unavailable`=2, `50 MB`=3, `video/quicktime`=2; negativos `nao e suportado`=0, `uma arte criada pela API tem`=0, `devolve 400`=0; cabecalhos `POST /artes`=1 e `GET /artes`=1; nenhuma chave `ak_` real (0 ocorrencias de `ak_` + 8 hex).
- `bin/rubocop app/controllers/api test/controllers/api`: 27 arquivos, sem ofensas.
- `bin/brakeman -q --no-pager -z`: sem avisos.
- Suites IA + admin artes + model arte + isolamento por cliente: **115 runs, 601 assertions, 0 failures, 0 errors, 0 skips** (piso 114).
- Escopo: `git diff --name-only 3184e92 -- app config db lib Gemfile Gemfile.lock` lista so `app/controllers/api/v1/ai/artes_controller.rb`; em `test docs` lista so `docs/api-ia.md` e `test/controllers/api/v1/ai/artes_controller_test.rb`. Helpers `tmp/ai_upload_*` nao estao no indice.
- As suites rodaram localmente pela receita do banco de teste pessoal por socket Unix, com preload que anula so a chave `api.ai_key`. A suite completa do projeto, `bin/bundler-audit` e `bin/importmap audit` nao foram executados aqui (dependem do CI/rede; nenhuma dependencia mudou, o que o gate de escopo prova).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `requirements: [TBD]` no frontmatter nao e um ID de requisito real; `requirements mark-complete` foi ignorado.

## Human Check Pendente (NAO verificado)

Verificacao humana de fim de fase, a colher no UAT. **O limite de body do proxy e o envio real ao S3/MinIO nao foram verificados por esta execucao.**

- **Teste:** apos o deploy, com a chave `ak_` real e um cliente de TESTE, enviar um arquivo real de cerca de 20 MB (por exemplo um mp4) pela URL publica: `curl -X POST "https://<host-publico>/api/v1/ai/artes" -H "Authorization: Bearer ak_..." -F client_id=<id do cliente de teste> -F scheduled_on=<data de hoje> -F platform=instagram -F media_type=video -F title="Teste de upload" -F media_file=@teste-20mb.mp4`.
- **Esperado:** HTTP 201 com `data.media_source_type` igual a "upload", `data.status` igual a "pending" e `data.media_url` que baixa o arquivo com o tamanho original. Se vier 413 (resposta sem o envelope JSON), o limite de body do nginx-proxy-manager barrou o upload: ajustar o proxy host (aba Advanced: `client_max_body_size 55m;`) e repetir. Depois, apagar a arte de teste pelo painel admin.
- **Por que humano:** o teto de body do proxy e a conectividade real com o S3/MinIO de producao nao estao no repositorio nem sao alcancaveis pelo CI; o limite do proxy ficou [ASSUMED] na pesquisa (Pitfall 5).

## Riscos aceitos

- Validacao cruzada `media_type` x tipo do arquivo fora de escopo.
- A identificacao por bytes (D-10) so vale com assinatura reconhecivel: um texto puro com nome `.jpg` e content type `image/jpeg` seria aceito.
- O upload e sincrono e ocupa uma thread do Puma; throttle de 60 pedidos por minuto inalterado (D-09).
- `media_url` e presigned e expira; a documentacao orienta a nao guarda-la e nao cita o prazo (nao verificado).
- Falha real do S3/MinIO foi provada com stub, nao contra o servico real.

## Known Stubs

None.

## Threat Flags

None - nenhuma superficie nova; T-33-10 (sem chave/URL reais na doc) coberta pelo gate de `ak_`, T-33-11 (proxy) pelo human-check acima, T-33-12 (doc obsoleta) pelos gates de remocao, T-33-SC (zero pacotes) pelo gate de escopo.

## Next Phase Readiness

Fase 33 com os dois planos executados; pronta para verificacao/UAT, que deve colher o human-check do proxy/S3.

## Self-Check: PASSED

- `docs/api-ia.md` e este SUMMARY existem; commit `6ca2d27` e ancestral de HEAD; criterios de aceitacao das duas tasks re-executados e verdes.
