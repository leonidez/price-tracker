require "test_helper"

class StoreAdapters::GenericTest < ActiveSupport::TestCase
  def http_fixture(name)
    Rails.root.join("test/fixtures/http", name).read
  end

  def adapter
    StoreAdapters::Generic.new(stores(:generic))
  end

  def generic_listing(url)
    listings(:widget_generic).tap { |listing| listing.update!(url: url) }
  end

  test "check returns a CheckResult on a parseable page" do
    url = "https://example.com/p"
    stub_request(:get, url).to_return(status: 200, body: http_fixture("jsonld_graph.html"))
    result = adapter.check(generic_listing(url))
    assert_equal 1299, result.price_cents
    assert_equal "USD", result.currency
    assert result.in_stock
    assert_equal "jsonld", result.source
  end

  test "check raises CheckFailed(:parse_failed) when no price is found" do
    url = "https://example.com/np"
    stub_request(:get, url).to_return(status: 200, body: http_fixture("no_price.html"))
    error = assert_raises(StoreAdapters::CheckFailed) { adapter.check(generic_listing(url)) }
    assert_equal :parse_failed, error.reason
  end

  test "check lets Http::BlockedError bubble on a 403" do
    url = "https://example.com/blocked"
    stub_request(:get, url).to_return(status: 403)
    assert_raises(Http::BlockedError) { adapter.check(generic_listing(url)) }
  end

  test "resolve is unsupported for the generic adapter" do
    error = assert_raises(StoreAdapters::ResolveFailed) { adapter.resolve(gtin13: "0036000291452") }
    assert_equal :unsupported, error.code
  end
end
