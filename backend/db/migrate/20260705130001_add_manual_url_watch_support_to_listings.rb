class AddManualUrlWatchSupportToListings < ActiveRecord::Migration[8.1]
  def change
    # Manual "by URL" watches have no barcode/product.
    change_column_null :listings, :product_id, true
    add_column :listings, :display_name, :string
  end
end
