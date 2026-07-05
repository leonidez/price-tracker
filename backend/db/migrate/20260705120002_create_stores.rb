class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :domain, null: false
      t.string :adapter, null: false
      t.json :config, default: {}
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :stores, :slug, unique: true
  end
end
