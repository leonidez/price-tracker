require "test_helper"

class Alerts::EvaluateTest < ActiveSupport::TestCase
  setup do
    @listing = listings(:cola_walmart)
    @watch = @listing.watches.create!(baseline_price_cents: 10_000, armed: true, active: true)
    @watch.alert_rules.create!(kind: "below_price", value_cents: 8_000)
  end

  def evaluate(cents, in_stock: true)
    price_point = @listing.price_points.create!(
      price_cents: cents, currency: "USD", checked_at: Time.current, in_stock: in_stock
    )
    Alerts::Evaluate.call(price_point: price_point)
  end

  test "truth table for a below_price $80 rule on baseline $100" do
    assert_empty evaluate(8_500),          "1. $85 should not notify"
    assert_equal 1, evaluate(7_900).size,  "2. $79 should notify"
    assert_not @watch.reload.armed?, "armed should be false after notifying"

    assert_empty evaluate(7_900),          "3. $79 again should not notify"
    assert_equal 1, evaluate(7_500).size,  "4. $75 should notify (lower than last)"
    assert_empty evaluate(7_600),          "5. $76 should not notify"

    assert_empty evaluate(9_000),          "6. $90 should not notify and re-arm"
    assert @watch.reload.armed?, "armed should be true again after a non-triggering check"

    assert_equal 1, evaluate(7_900).size,  "7. $79 after re-arm should notify"
  end

  test "OR'd rules: percent_drop 50% + below_price $80 on baseline $100" do
    @watch.alert_rules.create!(kind: "percent_drop", value_pct: 50)
    assert_equal 1, evaluate(7_900).size,  "$79 triggers below_price"
    assert_equal 1, evaluate(6_000).size,  "$60 triggers and is lower than last notified $79"
  end

  test "out-of-stock price point is skipped entirely (armed unchanged)" do
    @watch.update!(armed: false)
    assert_empty evaluate(7_000, in_stock: false)
    assert_not @watch.reload.armed?
  end

  test "inactive watch is not evaluated" do
    @watch.update!(active: false, armed: false)
    assert_empty evaluate(7_000)
    assert_not @watch.reload.armed?
  end

  test "no notification is created just for a non-triggering check" do
    assert_no_difference("Notification.count") { evaluate(9_500) }
  end

  test "predicates trigger at their exact thresholds" do
    below = @watch.alert_rules.new(kind: "below_price", value_cents: 8_000)
    assert Alerts::Evaluate.rule_triggered?(below, baseline_price_cents: 10_000, price_cents: 8_000)
    assert_not Alerts::Evaluate.rule_triggered?(below, baseline_price_cents: 10_000, price_cents: 8_001)

    amount = @watch.alert_rules.new(kind: "amount_drop", value_cents: 2_000)
    assert Alerts::Evaluate.rule_triggered?(amount, baseline_price_cents: 10_000, price_cents: 8_000)
    assert_not Alerts::Evaluate.rule_triggered?(amount, baseline_price_cents: 10_000, price_cents: 8_001)

    percent = @watch.alert_rules.new(kind: "percent_drop", value_pct: 20) # threshold = 8000
    assert Alerts::Evaluate.rule_triggered?(percent, baseline_price_cents: 10_000, price_cents: 8_000)
    assert_not Alerts::Evaluate.rule_triggered?(percent, baseline_price_cents: 10_000, price_cents: 8_001)
  end

  test "returns the created Notification records" do
    result = evaluate(7_000)
    assert_equal 1, result.size
    assert_instance_of Notification, result.first
    assert_equal 7_000, result.first.notified_price_cents
    assert result.first.price_alert?
  end
end
