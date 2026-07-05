class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :expo_push_token, null: false
      t.string :platform
      t.boolean :active, default: true, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :devices, :expo_push_token, unique: true
  end
end
