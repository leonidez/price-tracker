module StoreAdapters
  # Raised when a store names an adapter not present in the registry allowlist.
  class UnknownAdapter < Error; end
end
