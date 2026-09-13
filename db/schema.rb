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

ActiveRecord::Schema[8.1].define(version: 2026_09_13_013348) do
  create_table "assessments", force: :cascade do |t|
    t.date "ard"
    t.string "assessment_type"
    t.integer "check_id"
    t.datetime "created_at", null: false
    t.string "focus_item_id"
    t.integer "resident_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["check_id"], name: "index_assessments_on_check_id"
    t.index ["resident_id"], name: "index_assessments_on_resident_id"
  end

  create_table "checks", force: :cascade do |t|
    t.date "ard"
    t.text "chart_text"
    t.datetime "created_at", null: false
    t.text "error"
    t.integer "facility_id"
    t.json "item_ids"
    t.json "results"
    t.string "status"
    t.datetime "updated_at", null: false
    t.json "usage"
    t.index ["facility_id"], name: "index_checks_on_facility_id"
  end

  create_table "facilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "residents", force: :cascade do |t|
    t.text "chart_text"
    t.datetime "created_at", null: false
    t.integer "facility_id", null: false
    t.string "label"
    t.datetime "updated_at", null: false
    t.index ["facility_id"], name: "index_residents_on_facility_id"
  end

  create_table "rule_reviews", force: :cascade do |t|
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.string "item_id"
    t.text "notes"
    t.integer "reviewer_id", null: false
    t.string "status"
    t.datetime "submitted_at"
    t.string "target"
    t.datetime "updated_at", null: false
    t.string "verdict"
    t.index ["item_id", "status"], name: "index_rule_reviews_on_item_id_and_status"
    t.index ["reviewer_id"], name: "index_rule_reviews_on_reviewer_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "dev_both_domains", default: false, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "facility_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["facility_id"], name: "index_users_on_facility_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "assessments", "checks"
  add_foreign_key "assessments", "residents"
  add_foreign_key "checks", "facilities"
  add_foreign_key "residents", "facilities"
  add_foreign_key "rule_reviews", "users", column: "reviewer_id"
  add_foreign_key "users", "facilities"
end
