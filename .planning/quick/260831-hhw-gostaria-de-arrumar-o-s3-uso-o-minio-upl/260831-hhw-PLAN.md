---
phase: quick/260831-hhw-gostaria-de-arrumar-o-s3-uso-o-minio-upl
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/tasks/storage_migration.rake
autonomous: true
requirements: []
---

<objective>
Corrigir a causa raiz de "URL pública quebrada" (NoSuchKey) para artes cujo
`ActiveStorage::Blob` aponta para o serviço `:amazon` (MinIO) sem o arquivo
realmente existir no bucket.

**Investigação feita nesta sessão:** o pedido original do usuário trazia uma
URL pública específica que, testada isoladamente, respondia 200 (objeto
público, criado fora do app). O usuário então confirmou que o problema real
aparece no hover/preview de arte no calendário admin, com erro `NoSuchKey`.
Reproduzi isso de 3 formas independentes contra os 3 registros existentes no
banco de dev (Artes 1/2/3, blobs `service_name: "amazon"`, filename
`sample.jpg` — nome batendo com o fixture de teste `test/fixtures/files/sample.jpg`,
criados em lote em 2026-08-30, sem cópia em `storage/` local):
`ActiveStorage::Blob#service.exist?` -> `false`; SDK `object.get` ->
`Aws::S3::Errors::NoSuchKey`; uma URL presignada nova (`blob.url`) buscada via
curl -> `404 NoSuchKey`. Os 3 são registros órfãos de dev/teste (decisão do
usuário: deixar como estão, não são dados reais de cliente).

**Bug de código real, separado dos dados órfãos:** `lib/tasks/storage_migration.rake`
tinha um backfill final incondicional:
```ruby
ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")
```
Isso rodava em TODOS os blobs com `service_name` nil/"local", inclusive nos
que o próprio loop, linhas acima, tinha acabado de logar como
`"MISSING at source"` (sem arquivo nem no Disk local nem no MinIO — nada foi
copiado). Esses blobs ficavam marcados `service_name: "amazon"` sem o objeto
existir no bucket -- exatamente o padrão de erro reproduzido acima. Se essa
rake task for rodada de novo no futuro (uso normal dela, por design idempotente),
esse bug volta a acontecer para qualquer blob novo nessa situação.

Purpose: escopar o backfill só aos blobs CONFIRMADOS no destino (copiados
nesta run ou já presentes lá antes dela) -- nunca aos "MISSING at source".
Output: `storage:migrate_to_s3` nunca mais marca um blob como `amazon` sem o
objeto de fato existir no bucket.
</objective>

<context>
@lib/tasks/storage_migration.rake
@config/storage.yml
</context>

<tasks>

<task type="auto">
  <name>Task 1: Escopar o backfill de service_name aos blobs confirmados no destino</name>
  <files>lib/tasks/storage_migration.rake</files>
  <action>
Em `lib/tasks/storage_migration.rake`, dentro do loop `ActiveStorage::Blob.find_each`,
acumular um array `confirmed_at_dest_ids` com o `blob.id` de cada blob que:
(a) já existia no destino (`dest.exist?(blob.key)` true, ramo "skip"), OU
(b) foi copiado com sucesso nesta run (depois do `dest.upload`, ramo "copied").
NÃO adicionar ao array o ramo "MISSING at source" (nem no disco local nem no
destino -- nada foi copiado, nada foi confirmado).

Trocar o backfill final de:
`ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")`
para:
`ActiveStorage::Blob.where(service_name: [nil, "local"], id: confirmed_at_dest_ids).update_all(service_name: "amazon")`

Atualizar o comentário de cabeçalho do arquivo explicando o porquê do fix
(referenciar quick/260831-hhw) e o log da linha "MISSING at source" para deixar
claro que o `service_name` é deixado intocado nesse caso (evita reintroduzir o
bug silenciosamente numa edição futura). Não alterar mais nada no arquivo --
o comportamento idempotente/copy-only (D-05) e os 3 registros órfãos
já existentes no banco de dev permanecem intocados (decisão do usuário).
  </action>
  <verify>
    <automated>ruby -c lib/tasks/storage_migration.rake</automated>
  </verify>
  <done>
`lib/tasks/storage_migration.rake` acumula `confirmed_at_dest_ids` durante o
loop e o backfill final usa `id: confirmed_at_dest_ids` além do filtro por
`service_name`. Verificado nesta sessão via dois cenários controlados rodando
a task de verdade (`Rake::Task["storage:migrate_to_s3"].invoke`): um blob
"local" com arquivo real foi copiado E marcado `amazon` (comportamento
correto preservado); um blob "local" sem arquivo em lugar nenhum
("MISSING at source") permaneceu `service_name: "local"` -- não virou
`amazon` incorretamente, ao contrário do comportamento antes do fix.
  </done>
</task>

</tasks>

<verification>
1. `lib/tasks/storage_migration.rake` só marca `service_name: "amazon"` para
   blobs confirmados no destino (copiados ou já presentes).
2. Um blob "MISSING at source" nunca mais recebe `service_name: "amazon"`
   automaticamente -- comportamento verificado ao vivo, rodando a task real
   contra dois blobs de teste criados e destruídos nesta sessão.
3. Comportamento pré-existente para o caso "copiado com sucesso" e "já
   presente no destino" continua idêntico ao original (regressão zero).
</verification>

<success_criteria>
- Rodar `storage:migrate_to_s3` novamente no futuro nunca mais cria um
  registro que aponte para `amazon` sem o objeto realmente existir no bucket
  MinIO.
- Os 3 registros órfãos já existentes (Artes 1/2/3, dados de dev/teste)
  permanecem como estão, por decisão explícita do usuário -- nenhuma ação de
  dado nesta task.
</success_criteria>

<output>
Create `.planning/quick/260831-hhw-gostaria-de-arrumar-o-s3-uso-o-minio-upl/260831-hhw-SUMMARY.md` when done
</output>
