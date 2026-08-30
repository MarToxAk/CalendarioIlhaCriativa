# frozen_string_literal: true

# INFRA-01 / CONTEXT.md D-04 & D-05 · 25-RESEARCH.md Pattern 6 & Pitfall 6.
#
# Copies every pre-existing local Disk blob into the :amazon (MinIO) service and
# backfills active_storage_blobs.service_name for rows the old single-service
# setup left as NULL or "local" (Pitfall 6 — Rails honours a populated
# service_name column and would keep serving those artes from Disk otherwise).
#
# Idempotent + copy-only (D-05): re-running is a no-op, the source Disk store is
# never mutated or deleted (it stays as a fallback). Run it by hand on the
# deployed host after config.active_storage.service = :amazon is live and before
# the app serves traffic.
#
# Logs the blob key, byte size, and a status word only — never blob contents,
# never a (presigned) URL. Re-count the source at run time; never gate on a
# hardcoded blob count.
namespace :storage do
  desc "Copy local Disk blobs to the :amazon (MinIO) service + backfill service_name. Idempotent, copy-only."
  task migrate_to_s3: :environment do
    source = ActiveStorage::Blob.services.fetch(:local)
    dest   = ActiveStorage::Blob.services.fetch(:amazon)

    say = ->(msg) { Rails.logger.info(msg); puts msg }

    say.call("[storage:migrate] source inventory — total blobs: #{ActiveStorage::Blob.count}")
    say.call("[storage:migrate] service_name histogram: #{ActiveStorage::Blob.group(:service_name).count.inspect}")

    copied = 0
    skipped = 0
    missing = 0

    ActiveStorage::Blob.find_each do |blob|
      if dest.exist?(blob.key)
        skipped += 1
        say.call("[storage:migrate] skip #{blob.key} (already at destination)")
        next
      end

      unless source.exist?(blob.key)
        missing += 1
        say.call("[storage:migrate] MISSING at source: #{blob.key} (blob ##{blob.id})")
        next
      end

      dest.upload(
        blob.key,
        StringIO.new(source.download(blob.key)),
        checksum: blob.checksum,
        content_type: blob.content_type
      )
      copied += 1
      say.call("[storage:migrate] copied #{blob.key} (#{blob.byte_size} bytes)")
    end

    backfilled = ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")
    say.call("[storage:migrate] service_name backfill — rows updated: #{backfilled}")

    say.call(
      "[storage:migrate] done — copied: #{copied} skipped: #{skipped} " \
      "missing: #{missing} service_name_backfilled: #{backfilled}"
    )
  end
end
