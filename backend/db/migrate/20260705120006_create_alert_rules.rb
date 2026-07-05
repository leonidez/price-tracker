class CreateAlertRules < ActiveRecord::Migration[8.1]
  def change
    create_table :alert_rules do |t|
      t.references :watch, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :value_cents
      t.decimal :value_pct, precision: 5, scale: 2

      t.timestamps
    end
  end
end
