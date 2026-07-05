class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :gtin13, null: false
      t.string :barcode_raw
      t.string :name
      t.string :brand
      t.string :image_url

      t.timestamps
    end

    add_index :products, :gtin13, unique: true
  end
end
