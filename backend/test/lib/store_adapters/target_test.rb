require "test_helper"

class StoreAdapters::TargetTest < ActiveSupport::TestCase
  GTIN13 = "0036000291452".freeze
  UPC = "036000291452".freeze
  SEARCH = StoreAdapters::Target::SEARCH_ENDPOINT
  PDP = StoreAdapters::Target::PDP_ENDPOINT

  def http_fixture(name)
    Rails.root.join("test/fixtures/http", name).read
  end

  def configured_store
    stores(:target).tap { |s| s.update!(config: { "redsky_key" => "testkey", "store_id" => "3991" }) }
  end

  def adapter
    StoreAdapters::Target.new(configured_store)
  end

  def target_listing(url:, store_ref:)
    listings(:cola_walmart).tap do |listing|
      listing.update!(store: configured_store, url: url, store_ref: store_ref)
    end
  end

  def stub_search(keyword, fixture)
    stub_request(:get, SEARCH)
      .with(query: hash_including("keyword" => keyword))
      .to_return(status: 200, body: http_fixture(fixture))
  end

  test "missing config raises a clear ConfigurationError" do
    plain = StoreAdapters::Target.new(stores(:target))
    error = assert_raises(StoreAdapters::ConfigurationError) { plain.resolve(gtin13: GTIN13) }
    assert_match(/redsky_key/, error.message)
    assert_match(/store_id/, error.message)
  end

  test "resolve verifies via primary_barcode and returns the store price" do
    stub_search(UPC, "target_search.json")
    stub_request(:get, PDP).with(query: hash_including("tcin" => "54321"))
      .to_return(status: 200, body: http_fixture("target_pdp.json"))

    resolution = adapter.resolve(gtin13: GTIN13)
    assert resolution.verified
    assert_equal "54321", resolution.store_ref["tcin"]
    assert_equal 999, resolution.price_cents
    assert_equal "https://www.target.com/p/acme-cola-12pk/-/A-54321", resolution.url
    assert_equal "Acme Cola 12pk", resolution.title
  end

  test "resolve falls back to HTML search when RedSky returns nothing" do
    stub_search(UPC, "target_empty.json")
    stub_search(GTIN13, "target_empty.json")
    stub_request(:get, "https://www.target.com/s?searchTerm=#{UPC}")
      .to_return(status: 200, body: http_fixture("target_search_fallback.html"))

    resolution = adapter.resolve(gtin13: GTIN13)
    assert_not resolution.verified
    assert_equal "54321", resolution.store_ref["tcin"]
    assert_equal "https://www.target.com/p/acme-cola-12pk/-/A-54321", resolution.url
  end

  test "resolve raises not_found when RedSky and HTML both come up empty" do
    stub_search(UPC, "target_empty.json")
    stub_search(GTIN13, "target_empty.json")
    stub_request(:get, %r{https://www\.target\.com/s\?searchTerm=})
      .to_return(status: 200, body: "<html><body>no results</body></html>")

    error = assert_raises(StoreAdapters::ResolveFailed) { adapter.resolve(gtin13: GTIN13) }
    assert_equal :not_found, error.code
  end

  test "check via tcin reads the store price from the PDP" do
    stub_request(:get, PDP).with(query: hash_including("tcin" => "54321"))
      .to_return(status: 200, body: http_fixture("target_pdp.json"))

    listing = target_listing(url: "https://www.target.com/p/acme-cola-12pk/-/A-54321", store_ref: { "tcin" => "54321" })
    result = adapter.check(listing)
    assert_equal 999, result.price_cents
    assert_equal "redsky", result.source
    assert result.in_stock
  end

  test "check falls back to HTML extraction when RedSky errors" do
    stub_request(:get, PDP).with(query: hash_including("tcin" => "54321")).to_return(status: 500)
    product_url = "https://www.target.com/p/acme-cola-12pk/-/A-54321"
    stub_request(:get, product_url).to_return(status: 200, body: http_fixture("jsonld_graph.html"))

    listing = target_listing(url: product_url, store_ref: { "tcin" => "54321" })
    result = adapter.check(listing)
    assert_equal 1299, result.price_cents
    assert_equal "jsonld", result.source
  end

  test "check raises CheckFailed when both RedSky and HTML fail" do
    stub_request(:get, PDP).with(query: hash_including("tcin" => "54321")).to_return(status: 500)
    product_url = "https://www.target.com/p/mystery/-/A-54321"
    stub_request(:get, product_url).to_return(status: 200, body: http_fixture("no_price.html"))

    listing = target_listing(url: product_url, store_ref: { "tcin" => "54321" })
    error = assert_raises(StoreAdapters::CheckFailed) { adapter.check(listing) }
    assert_equal :parse_failed, error.reason
  end
end
