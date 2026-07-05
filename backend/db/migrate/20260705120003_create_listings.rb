class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :product, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.string :url, null: false
      t.json :store_ref, default: {}
      t.string :currency, default: "USD"
      t.string :status, default: "active"
      t.integer :consecutive_failures, default: 0, null: false
      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :listings, [ :product_id, :store_id ], unique: true
  end
end
