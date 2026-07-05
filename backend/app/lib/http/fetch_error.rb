module Http
  # Raised on timeouts, 5xx responses, and connection errors.
  class FetchError < StandardError; end
end
