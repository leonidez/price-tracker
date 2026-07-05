module StoreAdapters
  # Result of a price/stock check on a listing.
  CheckResult = Data.define(:price_cents, :currency, :in_stock, :source)
end
