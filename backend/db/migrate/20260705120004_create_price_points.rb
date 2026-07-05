class CreatePricePoints < ActiveRecord::Migration[8.1]
  def change
    create_table :price_points do |t|
      t.references :listing, null: false, foreign_key: true
      t.integer :price_cents, null: false
      t.string :currency, null: false
      t.boolean :in_stock, default: true, null: false
      t.datetime :checked_at, null: false
      t.string :source

      t.timestamps
    end

    add_index :price_points, [ :listing_id, :checked_at ]
  end
end
