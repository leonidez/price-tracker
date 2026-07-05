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

ActiveRecord::Schema[8.1].define(version: 2026_07_05_120008) do
  create_table "alert_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "updated_at", null: false
    t.integer "value_cents"
    t.decimal "value_pct", precision: 5, scale: 2
    t.integer "watch_id", null: false
    t.index ["watch_id"], name: "index_alert_rules_on_watch_id"
  end

  create_table "devices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "expo_push_token", null: false
    t.datetime "last_seen_at"
    t.string "platform"
    t.datetime "updated_at", null: false
    t.index ["expo_push_token"], name: "index_devices_on_expo_push_token", unique: true
  end

  create_table "listings", force: :cascade do |t|
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD"
    t.datetime "last_checked_at"
    t.integer "product_id", null: false
    t.string "status", default: "active"
    t.integer "store_id", null: false
    t.json "store_ref", default: {}
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["product_id", "store_id"], name: "index_listings_on_product_id_and_store_id", unique: true
    t.index ["product_id"], name: "index_listings_on_product_id"
    t.index ["store_id"], name: "index_listings_on_store_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "notified_price_cents"
    t.integer "price_point_id"
    t.string "push_status"
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.integer "watch_id", null: false
    t.index ["price_point_id"], name: "index_notifications_on_price_point_id"
    t.index ["watch_id"], name: "index_notifications_on_watch_id"
  end

  create_table "price_points", force: :cascade do |t|
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.boolean "in_stock", default: true, null: false
    t.integer "listing_id", null: false
    t.integer "price_cents", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["listing_id", "checked_at"], name: "index_price_points_on_listing_id_and_checked_at"
    t.index ["listing_id"], name: "index_price_points_on_listing_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "barcode_raw"
    t.string "brand"
    t.datetime "created_at", null: false
    t.string "gtin13", null: false
    t.string "image_url"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["gtin13"], name: "index_products_on_gtin13", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "adapter", null: false
    t.json "config", default: {}
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_stores_on_slug", unique: true
  end

  create_table "watches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "armed", default: true, null: false
    t.integer "baseline_price_cents", null: false
    t.datetime "created_at", null: false
    t.integer "listing_id", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_watches_on_listing_id"
  end

  add_foreign_key "alert_rules", "watches"
  add_foreign_key "listings", "products"
  add_foreign_key "listings", "stores"
  add_foreign_key "notifications", "price_points"
  add_foreign_key "notifications", "watches"
  add_foreign_key "price_points", "listings"
  add_foreign_key "watches", "listings"
end
