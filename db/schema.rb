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

ActiveRecord::Schema[8.1].define(version: 2026_11_24_010000) do
  create_table "episode_comments", force: :cascade do |t|
    t.integer "watchlist_item_id", null: false
    t.integer "user_id"
    t.integer "season", null: false
    t.integer "episode", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_episode_comments_on_user_id"
    t.index ["watchlist_item_id", "season", "episode", "created_at"], name: "index_episode_comments_on_item_and_position"
    t.check_constraint "length(body) BETWEEN 1 AND 1000", name: "episode_comments_body_length_check"
    t.check_constraint "season >= 1 AND episode >= 1", name: "episode_comments_position_check"
  end

  create_table "episode_progresses", force: :cascade do |t|
    t.integer "watchlist_item_id", null: false
    t.integer "user_id", null: false
    t.integer "season", null: false
    t.integer "episode", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_episode_progresses_on_user_id"
    t.index ["watchlist_item_id", "user_id"], name: "index_episode_progresses_on_watchlist_item_id_and_user_id", unique: true
    t.index ["watchlist_item_id"], name: "index_episode_progresses_on_watchlist_item_id"
    t.check_constraint "season >= 1 AND episode >= 1", name: "episode_progresses_position_check"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "invite_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_code"], name: "index_groups_on_invite_code", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "member", null: false
    t.index ["group_id", "user_id"], name: "index_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role IN ('member', 'owner')", name: "memberships_role_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "suggestions", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "suggested_by_id"
    t.string "title", null: false
    t.string "title_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tmdb_id"
    t.string "media_type"
    t.text "overview"
    t.integer "release_year"
    t.float "tmdb_rating"
    t.string "age_rating"
    t.string "poster_path"
    t.string "manual_media_type"
    t.index ["group_id", "media_type", "tmdb_id"], name: "index_suggestions_on_group_id_and_media_type_and_tmdb_id", unique: true, where: "tmdb_id IS NOT NULL"
    t.index ["group_id", "title_key"], name: "index_suggestions_on_group_id_and_title_key", unique: true, where: "tmdb_id IS NULL"
    t.index ["suggested_by_id"], name: "index_suggestions_on_suggested_by_id"
    t.check_constraint "(tmdb_id IS NULL AND media_type IS NULL) OR (tmdb_id IS NOT NULL AND tmdb_id > 0 AND media_type IS NOT NULL AND media_type IN ('movie', 'tv'))", name: "suggestions_catalog_identity_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "display_name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.integer "suggestion_id", null: false
    t.integer "user_id", null: false
    t.string "rating", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["suggestion_id", "user_id"], name: "index_votes_on_suggestion_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.check_constraint "rating IN ('love', 'maybe', 'not_interested')", name: "votes_rating_check"
  end

  create_table "watchlist_items", force: :cascade do |t|
    t.integer "group_id", null: false
    t.string "title", null: false
    t.boolean "watched", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tmdb_id"
    t.string "media_type"
    t.text "overview"
    t.integer "release_year"
    t.float "tmdb_rating"
    t.string "age_rating"
    t.string "poster_path"
    t.integer "source_suggestion_id"
    t.json "season_lengths"
    t.datetime "season_lengths_checked_at"
    t.string "manual_media_type"
    t.index ["group_id", "media_type", "tmdb_id"], name: "index_watchlist_items_on_group_id_and_media_type_and_tmdb_id", unique: true, where: "tmdb_id IS NOT NULL"
    t.index ["group_id"], name: "index_watchlist_items_on_group_id"
    t.index ["source_suggestion_id"], name: "index_watchlist_items_on_source_suggestion_id", unique: true
    t.check_constraint "(tmdb_id IS NULL AND media_type IS NULL) OR (tmdb_id IS NOT NULL AND tmdb_id > 0 AND media_type IS NOT NULL AND media_type IN ('movie', 'tv'))", name: "watchlist_items_catalog_identity_check"
  end

  add_foreign_key "episode_comments", "users", on_delete: :nullify
  add_foreign_key "episode_comments", "watchlist_items", on_delete: :cascade
  add_foreign_key "episode_progresses", "users", on_delete: :cascade
  add_foreign_key "episode_progresses", "watchlist_items", on_delete: :cascade
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "suggestions", "groups", on_delete: :cascade
  add_foreign_key "suggestions", "users", column: "suggested_by_id", on_delete: :nullify
  add_foreign_key "votes", "suggestions", on_delete: :cascade
  add_foreign_key "votes", "users", on_delete: :cascade
  add_foreign_key "watchlist_items", "groups"
  add_foreign_key "watchlist_items", "suggestions", column: "source_suggestion_id", on_delete: :nullify
end
