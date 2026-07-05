require "test_helper"

class PushCopyTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:cola_walmart)
    @watch = @listing.watches.create!(baseline_price_cents: 10_000, armed: true, active: true)
  end

  def price_alert(cents)
    point = @listing.price_points.create!(price_cents: cents, currency: "USD", checked_at: Time.current)
    @watch.notifications.create!(kind: "price_alert", price_point: point, notified_price_cents: cents)
  end

  test "format_cents renders integer cents as currency" do
    assert_equal "$12.34", PushCopy.format_cents(1234)
    assert_equal "$0.09", PushCopy.format_cents(9)
    assert_equal "€5.00", PushCopy.format_cents(500, "EUR")
    assert_equal "£100.00", PushCopy.format_cents(10_000, "GBP")
  end

  test "percent_off computes the drop from baseline" do
    assert_equal 25, PushCopy.percent_off(10_000, 7_500)
    assert_equal 0, PushCopy.percent_off(0, 5_000)
  end

  test "price_alert copy includes name, price, store, percent and amount" do
    notification = price_alert(7_500)
    assert_equal "📉 #{@listing.resolved_name} — $75.00", PushCopy.title(notification)

    body = PushCopy.body(notification)
    assert_includes body, "Now $75.00 at Walmart"
    assert_includes body, "25%"
    assert_includes body, "$25.00 below your $100.00"
  end

  test "parse_failure copy explains the problem" do
    notification = @watch.notifications.create!(kind: "parse_failure")
    assert_equal "⚠️ Can't check #{@listing.resolved_name}", PushCopy.title(notification)
    assert_includes PushCopy.body(notification), "stopped returning a price"
  end
end
