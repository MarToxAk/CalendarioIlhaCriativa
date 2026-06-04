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

ActiveRecord::Schema[8.1].define(version: 2026_06_04_121724) do
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

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "agency_name", default: "Ilha Criativa", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approval_responses", "artes"
  add_foreign_key "artes", "clients"
  add_foreign_key "sessions", "users"
end
