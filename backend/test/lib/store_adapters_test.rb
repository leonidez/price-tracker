require "test_helper"

class StoreAdaptersTest < ActiveSupport::TestCase
  teardown { StoreAdapters.reset_registry! }

  test "for returns the adapter instance named by the store" do
    assert_instance_of StoreAdapters::Generic, StoreAdapters.for(stores(:generic))
    assert_instance_of StoreAdapters::Walmart, StoreAdapters.for(stores(:walmart))
    assert_instance_of StoreAdapters::Target, StoreAdapters.for(stores(:target))
  end

  test "for raises UnknownAdapter for an adapter not in the allowlist" do
    store = Store.new(name: "X", slug: "x", domain: "x.com", adapter: "nope")
    assert_raises(StoreAdapters::UnknownAdapter) { StoreAdapters.for(store) }
  end

  test "a FakeAdapter can be registered and injected without a DB change" do
    StoreAdapters.register("fake", FakeAdapter)
    store = Store.new(name: "Fake", slug: "fake", domain: "", adapter: "fake")
    assert_instance_of FakeAdapter, StoreAdapters.for(store)
  end

  test "reset_registry! drops test registrations" do
    StoreAdapters.register("fake", FakeAdapter)
    StoreAdapters.reset_registry!
    store = Store.new(name: "Fake", slug: "fake", domain: "", adapter: "fake")
    assert_raises(StoreAdapters::UnknownAdapter) { StoreAdapters.for(store) }
  end

  test "placeholder adapters raise NotImplementedError until #6/#7" do
    assert_raises(NotImplementedError) do
      StoreAdapters.for(stores(:walmart)).check(listings(:cola_walmart))
    end
    assert_raises(NotImplementedError) do
      StoreAdapters.for(stores(:target)).resolve(gtin13: "0036000291452")
    end
  end
end
