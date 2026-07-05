class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :watch, null: false, foreign_key: true
      t.references :price_point, null: true, foreign_key: true
      t.string :kind, null: false
      t.integer :notified_price_cents
      t.datetime :sent_at
      t.string :push_status

      t.timestamps
    end
  end
end
