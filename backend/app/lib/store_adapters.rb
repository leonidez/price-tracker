# Store adapter framework. Each `stores` row names an adapter (by its `adapter`
# column) resolved here through an explicit allowlist — never constantize.
#
# Adapters have two duties: resolve(gtin13:) a barcode to a product page, and
# check(listing) the current price/stock. See docs/DESIGN.md § Store adapters.
module StoreAdapters
  module_function

  # adapter name -> class. Kept explicit (no constantize) so only known adapters
  # can ever be instantiated. Tests can `register` a FakeAdapter and later
  # `reset_registry!` without touching any store rows.
  def default_registry
    {
      "walmart" => Walmart,
      "target" => Target,
      "generic" => Generic
    }
  end

  def registry
    @registry ||= default_registry
  end

  def register(adapter_name, klass)
    registry[adapter_name.to_s] = klass
  end

  def reset_registry!
    @registry = default_registry
  end

  # Build the adapter instance for a store, or raise UnknownAdapter.
  def for(store)
    klass = registry[store.adapter.to_s]
    raise UnknownAdapter, "no adapter registered for #{store.adapter.inspect}" unless klass

    klass.new(store)
  end
end
