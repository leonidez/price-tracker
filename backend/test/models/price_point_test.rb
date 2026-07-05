require "test_helper"

class PricePointTest < ActiveSupport::TestCase
  def listing
    listings(:cola_walmart)
  end

  test "valid price point" do
    pp = listing.price_points.new(price_cents: 999, currency: "USD", checked_at: Time.current)
    assert pp.valid?
  end

  test "requires price_cents, currency, checked_at" do
    pp = PricePoint.new(listing: listing)
    assert_not pp.valid?
    assert pp.errors[:price_cents].present?
    assert pp.errors[:currency].present?
    assert pp.errors[:checked_at].present?
  end
end
