---
status: complete
---

# Corrigir URL pública do MinIO/S3 quebrada (NoSuchKey)

**Tasks:** 1/1

**Investigação:** a URL pública que o usuário colou originalmente (fora do
app, testada isoladamente) na verdade respondia 200. O sintoma real —
confirmado pelo usuário — era `NoSuchKey` ao passar o mouse/clicar numa arte
no calendário admin. Reproduzido de 3 formas independentes contra os 3
`ActiveStorage::Blob` existentes no banco de dev (Artes 1/2/3, filename
`sample.jpg`, `service_name: "amazon"`): `service.exist?` → `false`; SDK
`object.get` → `Aws::S3::Errors::NoSuchKey`; presigned URL fresca via curl →
`404 NoSuchKey`. São registros órfãos de dev/teste (nome bate com o fixture
`test/fixtures/files/sample.jpg`) — por decisão do usuário, ficam como estão,
sem limpeza de dado nesta task.

**Causa raiz de código (corrigida):** `lib/tasks/storage_migration.rake`
tinha um backfill final incondicional que marcava `service_name: "amazon"`
para TODO blob nil/"local", inclusive os que o próprio loop tinha acabado de
logar como `"MISSING at source"` (sem arquivo real em lugar nenhum). Isso
produz exatamente o padrão de erro reproduzido — um registro que afirma estar
no MinIO sem o objeto existir lá.

**Fix:** o backfill agora só roda sobre blobs confirmados no destino
(copiados nesta execução, ou já presentes lá antes dela) via um array
`confirmed_at_dest_ids` acumulado durante o loop.

**Verificação:** rodei a rake task de verdade (`Rake::Task["storage:migrate_to_s3"].invoke`)
contra dois cenários controlados criados e destruídos nesta sessão:
- Blob "local" com arquivo real → copiado e marcado `amazon` (comportamento
  correto preservado).
- Blob "local" sem arquivo em lugar nenhum (MISSING at source) → permaneceu
  `service_name: "local"`, não virou `amazon` incorretamente (bug corrigido).

**Arquivo alterado:** `lib/tasks/storage_migration.rake`

**Commit:** `d6c02ba`

**Não tocado (decisão do usuário):** os 3 registros órfãos existentes
(Artes 1/2/3) continuam com `service_name: "amazon"` sem arquivo real —
apenas dados de dev/teste, não requerem limpeza agora.
