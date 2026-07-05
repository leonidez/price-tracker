require "test_helper"

class StoreAdapters::WalmartTest < ActiveSupport::TestCase
  GTIN13 = "0036000291452".freeze
  UPC_SEARCH = "https://www.walmart.com/search?q=036000291452".freeze
  GTIN_SEARCH = "https://www.walmart.com/search?q=0036000291452".freeze
  PRODUCT_URL = "https://www.walmart.com/ip/Acme-Cola-12pk/12345".freeze

  def http_fixture(name)
    Rails.root.join("test/fixtures/http", name).read
  end

  def adapter
    StoreAdapters::Walmart.new(stores(:walmart))
  end

  def walmart_listing(url)
    listings(:cola_walmart).tap { |listing| listing.update!(url: url) }
  end

  test "resolve finds and verifies a candidate via the UPC-A search form" do
    stub_request(:get, UPC_SEARCH).to_return(status: 200, body: http_fixture("walmart_search.html"))
    stub_request(:get, PRODUCT_URL).to_return(status: 200, body: http_fixture("walmart_product.html"))

    resolution = adapter.resolve(gtin13: GTIN13)
    assert resolution.verified
    assert_equal PRODUCT_URL, resolution.url
    assert_equal 1299, resolution.price_cents
    assert_equal "USD", resolution.currency
    assert_equal "Acme Cola 12pk", resolution.title
  end

  test "resolve falls back to the 13-digit form when the UPC-A form has no hits" do
    stub_request(:get, UPC_SEARCH).to_return(status: 200, body: http_fixture("walmart_search_empty.html"))
    stub_request(:get, GTIN_SEARCH).to_return(status: 200, body: http_fixture("walmart_search.html"))
    stub_request(:get, PRODUCT_URL).to_return(status: 200, body: http_fixture("walmart_product.html"))

    assert adapter.resolve(gtin13: GTIN13).verified
    assert_requested :get, GTIN_SEARCH
  end

  test "resolve raises not_found when no candidate GTIN matches the scan" do
    other = "5901234123457" # does not start with 0 -> only the 13-digit search runs
    stub_request(:get, "https://www.walmart.com/search?q=#{other}")
      .to_return(status: 200, body: http_fixture("walmart_search.html"))
    stub_request(:get, PRODUCT_URL).to_return(status: 200, body: http_fixture("walmart_product.html"))

    error = assert_raises(StoreAdapters::ResolveFailed) { adapter.resolve(gtin13: other) }
    assert_equal :not_found, error.code
  end

  test "resolve raises not_found when search returns nothing" do
    stub_request(:get, UPC_SEARCH).to_return(status: 200, body: http_fixture("walmart_search_empty.html"))
    stub_request(:get, GTIN_SEARCH).to_return(status: 200, body: http_fixture("walmart_search_empty.html"))
    error = assert_raises(StoreAdapters::ResolveFailed) { adapter.resolve(gtin13: GTIN13) }
    assert_equal :not_found, error.code
  end

  test "resolve surfaces the bot-detection challenge as Http::BlockedError" do
    stub_request(:get, UPC_SEARCH).to_return(status: 200, body: http_fixture("walmart_blocked.html"))
    assert_raises(Http::BlockedError) { adapter.resolve(gtin13: GTIN13) }
  end

  test "check reads the price from product JSON-LD" do
    stub_request(:get, PRODUCT_URL).to_return(status: 200, body: http_fixture("walmart_product.html"))
    result = adapter.check(walmart_listing(PRODUCT_URL))
    assert_equal 1299, result.price_cents
    assert_equal "USD", result.currency
    assert result.in_stock
    assert_equal "jsonld", result.source
  end

  test "check falls back to __NEXT_DATA__ when there is no JSON-LD" do
    url = "https://www.walmart.com/ip/Store-Brand-Item/67890"
    stub_request(:get, url).to_return(status: 200, body: http_fixture("walmart_product_next_data.html"))
    result = adapter.check(walmart_listing(url))
    assert_equal 844, result.price_cents
    assert_equal "next_data", result.source
    assert result.in_stock
  end

  test "check raises CheckFailed(:parse_failed) on a priceless page" do
    url = "https://www.walmart.com/ip/Mystery/000"
    stub_request(:get, url).to_return(status: 200, body: http_fixture("no_price.html"))
    error = assert_raises(StoreAdapters::CheckFailed) { adapter.check(walmart_listing(url)) }
    assert_equal :parse_failed, error.reason
  end

  test "check lets Http::BlockedError bubble" do
    url = "https://www.walmart.com/ip/Blocked/999"
    stub_request(:get, url).to_return(status: 200, body: http_fixture("walmart_blocked.html"))
    assert_raises(Http::BlockedError) { adapter.check(walmart_listing(url)) }
  end
end
