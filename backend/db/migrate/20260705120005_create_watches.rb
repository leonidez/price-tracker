class CreateWatches < ActiveRecord::Migration[8.1]
  def change
    create_table :watches do |t|
      t.references :listing, null: false, foreign_key: true
      t.integer :baseline_price_cents, null: false
      t.boolean :armed, default: true, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
