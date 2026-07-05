require "test_helper"

class PriceExtractorTest < ActiveSupport::TestCase
  def fixture(name)
    Rails.root.join("test/fixtures/http", name).read
  end

  test "JSON-LD @graph Product with an Offer" do
    result = PriceExtractor.call(html: fixture("jsonld_graph.html"), url: "https://x")
    assert_equal 1299, result.price_cents
    assert_equal "USD", result.currency
    assert result.in_stock
    assert_equal "jsonld", result.method
    assert_includes result.gtins, "0001234500012"
  end

  test "JSON-LD AggregateOffer uses lowPrice and OutOfStock availability" do
    result = PriceExtractor.call(html: fixture("aggregate_offer.html"), url: "https://x")
    assert_equal 4500, result.price_cents
    assert_equal "USD", result.currency
    assert_not result.in_stock
    assert_equal "jsonld", result.method
    assert_includes result.gtins, "009876500018"
  end

  test "meta-only page uses product:price meta tags" do
    result = PriceExtractor.call(html: fixture("meta_only.html"), url: "https://x")
    assert_equal 1995, result.price_cents
    assert_equal "USD", result.currency
    assert_equal "meta", result.method
  end

  test "selector-only page uses the configured CSS selector" do
    result = PriceExtractor.call(
      html: fixture("selector_only.html"),
      url: "https://x",
      selector_config: { "price" => ".price-now", "currency" => "USD" }
    )
    assert_equal 749, result.price_cents
    assert_equal "USD", result.currency
    assert_equal "selector", result.method
  end

  test "selector tier is not used without a matching config" do
    assert_nil PriceExtractor.call(html: fixture("selector_only.html"), url: "https://x")
  end

  test "page with no price returns nil" do
    assert_nil PriceExtractor.call(html: fixture("no_price.html"), url: "https://x")
  end
end
