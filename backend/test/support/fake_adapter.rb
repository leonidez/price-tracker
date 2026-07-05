# Test-only adapter injected via StoreAdapters.register (see #9/#10 tests).
# Behavior is driven by class-level handlers set per test and reset in teardown.
class FakeAdapter < StoreAdapters::Base
  cattr_accessor :check_handler, :resolve_handler

  def self.reset!
    self.check_handler = nil
    self.resolve_handler = nil
  end

  def check(listing)
    raise "FakeAdapter.check_handler not set" unless self.class.check_handler

    self.class.check_handler.call(listing)
  end

  def resolve(gtin13:, hint: nil)
    raise "FakeAdapter.resolve_handler not set" unless self.class.resolve_handler

    self.class.resolve_handler.call(gtin13, hint)
  end
end
