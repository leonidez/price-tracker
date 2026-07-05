module StoreAdapters
  # Raised by #check when a price can't be determined. `reason` is e.g.
  # :parse_failed. (Http::BlockedError is left to bubble separately.)
  class CheckFailed < Error
    attr_reader :reason

    def initialize(reason: :parse_failed, message: nil)
      @reason = reason
      super(message || "check failed (#{reason})")
    end
  end
end
