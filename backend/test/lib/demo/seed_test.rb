require "test_helper"

class Demo::SeedTest < ActiveSupport::TestCase
  test "creates four demo watches covering every card state" do
    watches = Demo::Seed.call
    assert_equal 4, watches.size

    listings = watches.map(&:listing)
    assert listings.all? { |l| l.store.slug == "generic" }
    assert listings.any? { |l| l.parse_failed? }, "expected a parse_failed listing"
    assert watches.any? { |w| !w.active }, "expected an inactive watch"

    sale = watches.find { |w| w.listing.display_name.include?("Blender") }
    assert_operator sale.listing.latest_price_point.price_cents, :<, sale.baseline_price_cents

    assert_equal 30, listings.first.price_points.count
    assert watches.all? { |w| w.alert_rules.any? }
  end

  test "is idempotent (safe to run twice)" do
    Demo::Seed.call
    assert_no_difference([ "Watch.count", "Listing.count" ]) do
      Demo::Seed.call
    end
    # history is rebuilt, not appended
    assert_equal 30, Listing.find_by(url: "https://example.com/demo/blender").price_points.count
  end
end
