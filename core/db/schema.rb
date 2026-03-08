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

ActiveRecord::Schema[8.1].define(version: 2026_03_08_145945) do
  create_table "catalogs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "variant_display", default: "none", null: false
    t.index ["user_id", "name"], name: "index_catalogs_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_catalogs_on_user_id"
  end

  create_table "magic_tokens", force: :cascade do |t|
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token_digest"], name: "index_magic_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_magic_tokens_on_user_id"
  end

  create_table "participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dj_id", null: false
    t.datetime "last_active_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["dj_id", "name"], name: "index_participants_on_dj_id_and_name"
    t.index ["dj_id"], name: "index_participants_on_dj_id"
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "queue_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "participant_id", null: false
    t.datetime "performed_at"
    t.integer "position", null: false
    t.integer "show_id", null: false
    t.string "song_artist", null: false
    t.string "song_external_id"
    t.string "song_title", null: false
    t.string "song_version"
    t.string "status", default: "waiting", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_queue_entries_on_participant_id"
    t.index ["show_id", "position"], name: "index_queue_entries_on_show_id_and_position"
    t.index ["show_id", "status"], name: "index_queue_entries_on_show_id_and_status"
    t.index ["show_id"], name: "index_queue_entries_on_show_id"
  end

  create_table "shows", force: :cascade do |t|
    t.integer "catalog_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.integer "max_songs_per_singer"
    t.string "rotation_style", default: "standard", null: false
    t.string "show_type", default: "karaoke", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["catalog_id"], name: "index_shows_on_catalog_id"
    t.index ["user_id", "status"], name: "index_shows_on_user_id_and_status"
    t.index ["user_id"], name: "index_shows_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_max_songs_per_singer"
    t.string "default_rotation_style", default: "standard", null: false
    t.string "default_show_type", default: "karaoke", null: false
    t.string "email", null: false
    t.datetime "email_confirmed_at"
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "catalogs", "users"
  add_foreign_key "magic_tokens", "users"
  add_foreign_key "participants", "users"
  add_foreign_key "participants", "users", column: "dj_id"
  add_foreign_key "queue_entries", "participants"
  add_foreign_key "queue_entries", "shows"
  add_foreign_key "shows", "catalogs"
  add_foreign_key "shows", "users"
end
