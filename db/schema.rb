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

ActiveRecord::Schema[8.1].define(version: 2026_09_12_210205) do
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
    t.json "item_ids"
    t.json "results"
    t.string "status"
    t.datetime "updated_at", null: false
    t.json "usage"
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

  add_foreign_key "assessments", "checks"
  add_foreign_key "assessments", "residents"
  add_foreign_key "residents", "facilities"
end
