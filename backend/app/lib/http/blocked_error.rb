module Http
  # Raised when a request is blocked by bot-detection: HTTP 403/429 or a
  # caller-supplied challenge marker matching the body.
  class BlockedError < StandardError; end
end
