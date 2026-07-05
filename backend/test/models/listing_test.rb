require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "valid listing" do
    assert listings(:cola_walmart).valid?
  end

  test "requires url" do
    listing = listings(:cola_walmart)
    listing.url = nil
    assert_not listing.valid?
  end

  test "product+store pair is unique" do
    dup = Listing.new(product: products(:cola), store: stores(:walmart), url: "https://x")
    assert_not dup.valid?
    assert dup.errors[:product_id].present?
  end

  test "status enum round-trips" do
    listing = listings(:cola_walmart)
    %w[active parse_failed blocked archived].each do |status|
      listing.status = status
      assert_equal status, listing.status
      assert listing.public_send("#{status}?")
    end
  end

  test "latest_price_point returns the most recent by checked_at" do
    listing = listings(:cola_walmart)
    listing.price_points.create!(price_cents: 1000, currency: "USD", checked_at: 2.days.ago)
    newest = listing.price_points.create!(price_cents: 900, currency: "USD", checked_at: 1.hour.ago)
    assert_equal newest, listing.latest_price_point
  end

  test "destroying a listing destroys price_points and watches" do
    listing = listings(:cola_walmart)
    listing.price_points.create!(price_cents: 1000, currency: "USD", checked_at: Time.current)
    listing.watches.create!(baseline_price_cents: 1000)
    assert_difference([ "PricePoint.count", "Watch.count" ], -1) do
      listing.destroy
    end
  end
end
