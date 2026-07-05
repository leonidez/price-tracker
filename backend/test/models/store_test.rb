require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "valid store" do
    assert stores(:walmart).valid?
  end

  test "requires name, adapter, slug" do
    store = Store.new
    assert_not store.valid?
    assert store.errors[:name].present?
    assert store.errors[:adapter].present?
    assert store.errors[:slug].present?
  end

  test "slug is unique" do
    dup = Store.new(name: "X", slug: "walmart", domain: "x.com", adapter: "generic")
    assert_not dup.valid?
    assert dup.errors[:slug].present?
  end

  test "adapter_config symbolizes keys" do
    assert_equal({ redsky_key: nil, store_id: nil }, stores(:target).adapter_config)
    assert_equal({}, stores(:walmart).adapter_config)
  end
end
