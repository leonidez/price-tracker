module StoreAdapters
  # Raised when a store's config is missing values the adapter needs
  # (e.g. Target's redsky_key / store_id — see backend/README.md).
  class ConfigurationError < Error; end
end
