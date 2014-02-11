# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140209161556) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "authentications", force: true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.string   "token"
    t.string   "token_secret"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.text     "source_data"
  end

  create_table "boards", force: true do |t|
    t.string   "guid"
    t.string   "name"
    t.string   "url"
    t.string   "organization_id"
    t.text     "description"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.integer  "user_id"
  end

  add_index "boards", ["guid"], name: "index_boards_on_guid", using: :btree
  add_index "boards", ["user_id"], name: "index_boards_on_user_id", using: :btree

  create_table "lists", force: true do |t|
    t.string   "name"
    t.string   "guid"
    t.text     "contents"
    t.integer  "board_id"
    t.string   "webhook"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "lists", ["guid"], name: "index_lists_on_guid", unique: true, using: :btree

  create_table "notebook_boards", force: true do |t|
    t.integer  "notebook_id"
    t.integer  "board_id"
    t.integer  "user_id"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.integer  "list_id"
    t.text     "compiled_update_times"
    t.boolean  "share_flag"
    t.string   "in_progress",           array: true
  end

  add_index "notebook_boards", ["board_id"], name: "index_notebook_boards_on_board_id", using: :btree
  add_index "notebook_boards", ["in_progress"], name: "index_notebook_boards_on_in_progress", using: :btree
  add_index "notebook_boards", ["notebook_id"], name: "index_notebook_boards_on_notebook_id", using: :btree
  add_index "notebook_boards", ["user_id"], name: "index_notebook_boards_on_user_id", using: :btree

  create_table "notebooks", force: true do |t|
    t.string   "name"
    t.string   "guid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "user_id"
  end

  add_index "notebooks", ["guid"], name: "index_notebooks_on_guid", using: :btree
  add_index "notebooks", ["user_id"], name: "index_notebooks_on_user_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "email",                default: "", null: false
    t.string   "encrypted_password",   default: "", null: false
    t.integer  "sign_in_count",        default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "authentication_token"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.string   "name"
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree

end
