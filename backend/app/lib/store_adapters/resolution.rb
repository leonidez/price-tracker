module StoreAdapters
  # Result of resolving a barcode to a candidate product page.
  Resolution = Data.define(
    :url, :title, :image_url, :price_cents, :currency, :store_ref, :verified
  )
end
