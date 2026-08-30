# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_30_190002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "approval_responses", force: :cascade do |t|
    t.bigint "arte_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "decision", null: false
    t.datetime "responded_at"
    t.datetime "updated_at", null: false
    t.index ["arte_id"], name: "index_approval_responses_on_arte_id"
    t.index ["decision"], name: "index_approval_responses_on_decision"
  end

  create_table "artes", force: :cascade do |t|
    t.text "admin_reply"
    t.date "approval_deadline"
    t.text "caption"
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.string "external_url"
    t.integer "media_type", default: 0, null: false
    t.integer "platform", default: 0, null: false
    t.date "scheduled_on", null: false
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["client_id", "scheduled_on"], name: "index_artes_on_client_id_and_scheduled_on"
    t.index ["client_id"], name: "index_artes_on_client_id"
    t.index ["status"], name: "index_artes_on_status"
  end

  create_table "clients", force: :cascade do |t|
    t.string "access_token", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "password_plain"
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_clients_on_access_token", unique: true
  end

  create_table "divulgacao_grupos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "divulgacao_id", null: false
    t.string "error_code"
    t.string "evolution_message_id"
    t.string "group_name", null: false
    t.string "remote_jid", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "whatsapp_group_id", null: false
    t.index ["divulgacao_id", "whatsapp_group_id"], name: "index_divulgacao_grupos_on_divulgacao_id_and_whatsapp_group_id", unique: true
    t.index ["divulgacao_id"], name: "index_divulgacao_grupos_on_divulgacao_id"
    t.index ["whatsapp_group_id"], name: "index_divulgacao_grupos_on_whatsapp_group_id"
  end

  create_table "divulgacoes", force: :cascade do |t|
    t.bigint "arte_id", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "scheduled_for", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["arte_id"], name: "index_divulgacoes_on_arte_id"
    t.index ["client_id", "scheduled_for"], name: "index_divulgacoes_on_client_id_and_scheduled_for"
    t.index ["client_id"], name: "index_divulgacoes_on_client_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "agency_name", default: "Ilha Criativa", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "whatsapp_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "announce", default: false, null: false
    t.datetime "created_at", null: false
    t.string "remote_jid", null: false
    t.string "subject"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.bigint "whatsapp_instance_id", null: false
    t.index ["whatsapp_instance_id", "active"], name: "index_whatsapp_groups_on_whatsapp_instance_id_and_active"
    t.index ["whatsapp_instance_id", "remote_jid"], name: "index_whatsapp_groups_on_whatsapp_instance_id_and_remote_jid", unique: true
    t.index ["whatsapp_instance_id"], name: "index_whatsapp_groups_on_whatsapp_instance_id"
  end

  create_table "whatsapp_instances", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.integer "connection_state", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "groups_sync_error"
    t.integer "groups_sync_state", default: 0, null: false
    t.datetime "groups_synced_at"
    t.string "instance_name", null: false
    t.datetime "last_checked_at"
    t.text "last_error"
    t.text "last_qr_base64"
    t.integer "origin", default: 0, null: false
    t.datetime "paired_at"
    t.datetime "qr_expires_at"
    t.string "remote_instance_id"
    t.text "token"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_whatsapp_instances_on_client_id", unique: true
    t.index ["instance_name"], name: "index_whatsapp_instances_on_instance_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approval_responses", "artes"
  add_foreign_key "artes", "clients"
  add_foreign_key "divulgacao_grupos", "divulgacoes"
  add_foreign_key "divulgacao_grupos", "whatsapp_groups"
  add_foreign_key "divulgacoes", "artes"
  add_foreign_key "divulgacoes", "clients"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "whatsapp_groups", "whatsapp_instances"
  add_foreign_key "whatsapp_instances", "clients"
end
