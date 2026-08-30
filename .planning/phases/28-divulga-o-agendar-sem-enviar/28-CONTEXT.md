# Phase 28: Divulgação — Agendar sem Enviar - Context

**Gathered:** 2026-08-30
**Status:** Ready for planning

<domain>
## Phase Boundary

O admin monta e agenda uma Divulgação completa — cliente, arte aprovada, grupos e data/hora
— com todas as validações e o preview, **parando deliberadamente antes de qualquer envio**.
Esta fase entrega o schema (`divulgacoes` + `divulgacao_grupos`), o CRUD (`new`/`create`/
`index`/`show`), as validações de criação (DIVU-02..04, SEG-01/02), o preview (DIVU-06), a
estimativa de duração (DIVU-07) e a coluna/estado de cancelamento. **Fora de escopo:** o
motor de envio, qualquer job de disparo, qualquer chamada `sendText`/`sendMedia` ao Evolution
(tudo fase 29). Parar antes do envio torna o schema — a parte mais cara de errar —
verificável isoladamente e permite rollback do motor sem levar o CRUD junto.

</domain>

<decisions>
## Implementation Decisions

### Modelo de dados da Divulgação

- Duas tabelas: `divulgacoes` (`belongs_to :client`, `belongs_to :arte`) + `divulgacao_grupos`
  (`belongs_to :divulgacao`, `belongs_to :whatsapp_group`) — **uma linha por grupo** (DIVU-09).
- `divulgacao_grupos.status` enum: `pendente / enviado / falhou / incerto` (texto verbatim do
  DIVU-09). Default `pendente`. Nesta fase toda linha nasce e permanece `pendente` — as outras
  transições são da fase 29.
- `divulgacoes.status` enum: `agendada / em_andamento / concluida / cancelada`. Default
  `agendada`. A transição `cancelada` é acionável nesta fase (botão em `#show`); as demais são
  da fase 29. A coluna/estado precisa existir agora porque o motor da fase 29 lê para decidir
  se ainda envia.
- Referência ao grupo em `divulgacao_grupos`: FK `whatsapp_group_id` (escopada, para o motor
  re-resolver e revalidar) **+** snapshot congelado na criação: `group_name` (string, =
  `whatsapp_group.display_name` no instante da criação) e `remote_jid` (string). Se o grupo
  for depois desativado/renomeado, o histórico da Divulgação mantém o nome como estava
  (DIVU-09: "nome do grupo congelado como estava").
- Data/hora do envio: nova coluna `scheduled_for` (`datetime`, tz-aware) em `divulgacoes`.
  `Arte#scheduled_on` permanece **`date` sem hora, intocada** (DIVU-05). `scheduled_for` é
  independente de `arte.scheduled_on` — o admin escolhe quando disparar.
- Índices: `divulgacao_grupos [divulgacao_id, whatsapp_group_id]` único (um grupo não entra
  duas vezes na mesma Divulgação); `divulgacoes [client_id, scheduled_for]`.

### Validações na criação

- **Só artes aprovadas (DIVU-02):** o picker de arte lista apenas `@client.artes.approved`;
  o model revalida com `validate :arte_deve_estar_aprovada` no create (defense-in-depth — a
  arte pode ter mudado de status entre o carregamento do form e o submit).
- **Link externo recusado (DIVU-03):** na criação da Divulgação, recusa se
  `arte.external_url.present?` ou se `!arte.media_file.attached?`, com mensagem orientando:
  "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a
  divulgação." **Não altera nenhuma validação da `Arte`** — a Arte continua aceitando
  `external_url` para o fluxo de aprovação; só a Divulgação exige arquivo anexado.
- **Teto de arquivo (DIVU-04):** constante nível-Divulgação `WHATSAPP_MEDIA_MAX_BYTES`
  (valor exato a confirmar na pesquisa contra o contrato Evolution/WhatsApp 2.3.7 — ordem de
  grandeza: ~16 MB para vídeo/documento). Validação `validate :arquivo_dentro_do_teto_whatsapp`
  compara `arte.media_file.blob.byte_size` contra a constante. A validação de 50 MB da `Arte`
  **permanece intacta** — a Divulgação só adiciona um teto mais apertado no seu próprio create.
  Mensagem: diz o tamanho atual e o teto, e sugere comprimir/reenviar.
- **Cross-client + id cru (SEG-01/SEG-02):**
  - SEG-02: `validate :arte_e_grupos_do_mesmo_cliente` — `arte.client_id` deve ser igual a
    `divulgacao.client_id`; qualquer divergência recusa a criação.
  - SEG-01: o form nunca aceita `remote_jid` cru. Todo id submetido em
    `divulgacao[whatsapp_group_ids][]` é re-resolvido por
    `client.whatsapp_instance.whatsapp_groups.where(active: true).find(id)` — um id de outro
    cliente ou de grupo inativo levanta `RecordNotFound` e a criação é recusada. Mesmo padrão
    de `@client.artes.find` já usado no projeto.
  - Reusa o `_picker.html.erb` da fase 27 **verbatim**, agora com
    `field_name: "divulgacao[whatsapp_group_ids][]"` (checkboxes vivos, com `name`). A fase 27
    já provou o escopo read-only; esta fase liga o form control.

### Preview e estimativa de duração

- **Preview (DIVU-06):** card acima do botão "Agendar divulgação" mostrando (a) o render da
  **mídia real** — `image_tag` para imagem, `<video>` com o preview/variant do ActiveStorage
  para vídeo — e (b) a **legenda exatamente como será enviada**. É o que vai ao grupo, sem
  transformação.
- **Legenda anti-spam (decisão pendente do ROADMAP — RESOLVIDA):** **v1.7 envia a legenda
  VERBATIM.** Sem rotação/spinning/variação de legenda neste milestone. O cliente aprovou
  aquela legenda exata; qualquer mutação enviaria conteúdo não-aprovado. O risco de ban é
  mitigado **só** pelo intervalo aleatório entre grupos (fase 29, ENVIO-01/02), não por
  mutação de conteúdo. O preview mostra a legenda única. (Se um milestone futuro quiser
  variação, vira campo `caption_variants` + preview de todas as variações — deferido.)
- **Estimativa de duração (DIVU-07):** `n_grupos_selecionados × média(delay_min, delay_max)`,
  exibida como faixa humana ("≈ 8–14 min para 20 grupos"). Os valores de delay vêm das env
  vars da fase 29 (`ENVIO-02` — nomes exatos a confirmar na pesquisa); se ausentes no
  ambiente, usa defaults documentados e sinaliza que é estimativa. A estimativa atualiza
  quando o admin muda a seleção de grupos (Stimulus, cálculo client-side a partir de um
  data-attribute com o range, ou recomputo no submit — o UI-SPEC decide).
- **Layout:** **página única** (`divulgacoes#new`). Topo: seletor de arte + `_picker` de
  grupos + input de agendamento. Abaixo: card de preview + estimativa. Um submit
  "Agendar divulgação". Sem wizard multi-step.

### Rotas, navegação e fuso

- **Rota:** `resources :divulgacoes, only: [:index, :new, :create, :show]` aninhada em
  `namespace :admin { resources :clients { ... } }`, mesmo padrão de `whatsapp_groups`.
  `Admin::DivulgacoesController < Admin::BaseController`; `set_client` a partir de
  `Client.find(params[:client_id])`.
- **Fuso (DIVU-05):** todos os datetimes na tela renderizados com offset explícito — ex.
  "15/09/2025 14:00 (BRT)" ou "(America/Sao_Paulo)". O input do form é `datetime-local`
  interpretado em `Time.zone` (já `America/Sao_Paulo` como default do app — INFRA-03). Helper
  de formatação dedicado (pt-BR).
- **Ponto de entrada:** botão "Nova divulgação" no `admin/clients#show` (perto do painel
  WhatsApp) + uma seção listando as divulgações daquele cliente (`divulgacoes#index` embutido
  ou linkado). Sem item no menu lateral global nesta fase.
- **Cancelamento:** `divulgacoes#show` tem botão "Cancelar divulgação" (com
  `turbo_confirm`) → `PATCH` que seta `status: :cancelada`. Sem `destroy` — o registro e o
  histórico por grupo são preservados. A honra do cancelamento pelos envios não-realizados é
  DIVU-08 / fase 29; aqui só a coluna, o estado e a ação de UI.

### Claude's Discretion

- Nome exato do controller de cancelamento (action `cancel` custom vs `update` com
  state param) e verbo/rota.
- Se `divulgacao_grupos` ganha `sent_at` / `error_code` / `evolution_message_id` agora
  (colunas nulas prontas para a fase 29) ou se a fase 29 as adiciona — preferência: adicionar
  as colunas nulas agora para a fase 29 não mexer no schema, mas sem lógica.
- Estrutura exata do preview de vídeo (poster/variant vs `<video controls>` cru).
- Se a estimativa recalcula via Stimulus client-side ou só no re-render — seguir o UI-SPEC.
- Textos pt-BR exatos, classes Tailwind, ícones.
- Se `divulgacoes#index` é página própria ou só uma seção parcial no `clients#show`.
- Nome do helper de formatação de fuso e do arquivo de constantes do teto de mídia.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/admin/whatsapp_groups/_picker.html.erb` — picker escopado reutilizável,
  construído na fase 27 EXATAMENTE para esta fase. Aceita `client:`, `groups:`,
  `selected_ids:`, `field_name:`, `pagy:`. `field_name: nil` = read-only (fase 27);
  `field_name: "divulgacao[whatsapp_group_ids][]"` = form control vivo (esta fase).
- `_group_row.html.erb` — linha individual do picker, já usa `check_box_tag`.
- `Client#whatsapp_instance` (`has_one`), `whatsapp_instance.whatsapp_groups` (`has_many`),
  `Client has_many :whatsapp_groups, through: :whatsapp_instance`. `whatsapp_groups.active`.
- `Arte`: `enum :status { pending, approved, change_requested, revised }`,
  `has_one_attached :media_file`, `enum :media_type { image, video, caption_only }`,
  coluna `external_url` (string), coluna `caption` (text), `scheduled_on` (`date`, `null: false`).
  Validação de `media_file`: `content_type in %w[image/jpeg image/png image/gif video/mp4
  video/quicktime]`, `size < 50.megabytes`.
- Scoping pattern `@client.artes.find(params[:id])` → `RecordNotFound`/404 — usado em
  `app/controllers/client/artes_controller.rb` e replicado em
  `Admin::WhatsappGroupsController#set_group` (fase 27, `@client.whatsapp_instance.whatsapp_groups.find`).
- `Admin::BaseController` — `require_authentication` + `Pagy::Backend`. Todos os controllers
  admin herdam.

### Established Patterns
- Controllers admin aninhados sob `resources :clients` com `before_action :set_client`
  (`Client.find(params[:client_id])`). Ex.: `whatsapp_groups_controller.rb`,
  `whatsapp_instances_controller.rb`.
- `button_to` com `data: { turbo_submits_with: "…" }` para ações POST que mutam estado.
- `turbo_confirm` para confirmações destrutivas/perigosas (fase v1.3+).
- Migrations rodam contra o dev DB local; `bin/rails test` roda com
  `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo` (workaround de socket — `.env`
  bloqueado para agentes no sandbox).
- `Time.zone` = `America/Sao_Paulo`, `config.active_record.default_timezone = :local`,
  boot check `config/initializers/timezone_check.rb` (INFRA-03).
- pt-BR em toda UI e prosa de SUMMARY.

### Integration Points
- Nova rota aninhada em `config/routes.rb` sob `namespace :admin { resources :clients }`.
- Link/botão novo em `app/views/admin/clients/show.html.erb` (painel WhatsApp / lateral).
- Novos models `Divulgacao` e `DivulgacaoGrupo` em `app/models/`.
- `Client has_many :divulgacoes`; `Arte has_many :divulgacoes` (ou `has_one`? — múltiplas
  divulgações da mesma arte são plausíveis; usar `has_many`).
- `WhatsappGroup has_many :divulgacao_grupos` (para a fase 30 mostrar histórico por grupo).

</code_context>

<specifics>
## Specific Ideas

- O texto dos enums de `divulgacao_grupos.status` deve ser **exatamente** `pendente`,
  `enviado`, `falhou`, `incerto` — é o vocabulário do DIVU-09 e a fase 30 renderiza esses
  rótulos.
- A mensagem de recusa de link externo (DIVU-03) tem que **dizer o que fazer** ("faça o
  upload do arquivo na arte"), não só "inválido".
- A mensagem de teto de arquivo (DIVU-04) tem que **dizer o que fazer** (tamanho atual vs
  teto, sugestão de comprimir).
- O preview mostra a legenda **exata** — nada de placeholder ou "[legenda]".
- A estimativa é uma **faixa** ("8–14 min"), não um número único falsamente preciso.

</specifics>

<deferred>
## Deferred Ideas

- Variação de legenda anti-spam (`caption_variants`) — explicitamente fora do v1.7; a legenda
  vai verbatim. Reconsiderar em milestone futuro só se o risco de ban se provar real com a
  mitigação de delay.
- Normalização de links Drive/Dropbox para download direto (PROD-04) — no v1.7 são
  bloqueados, não normalizados.
- O motor de envio, jobs de disparo, `sendText`/`sendMedia`, idempotência de envio,
  revalidação de aprovação/conexão no momento do envio — tudo fase 29.
- Progresso ao vivo, reenvio por grupo, histórico consolidado por cliente — fase 30.
- Testes negativos cross-client de ponta a ponta (SEG-04) — fase 30 (esta fase tem os testes
  de validação de criação; o teste de que a arte de A não *alcança* grupos de B precisa do
  motor).

</deferred>
