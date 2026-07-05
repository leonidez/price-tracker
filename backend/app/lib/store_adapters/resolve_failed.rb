module StoreAdapters
  # Raised by #resolve. `code` is one of :not_found, :blocked, :unsupported.
  class ResolveFailed < Error
    attr_reader :code

    def initialize(code:, message: nil)
      @code = code
      super(message || "resolve failed (#{code})")
    end
  end
end
