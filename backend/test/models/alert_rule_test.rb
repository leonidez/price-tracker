require "test_helper"

class AlertRuleTest < ActiveSupport::TestCase
  def watch
    @watch ||= listings(:cola_walmart).watches.create!(baseline_price_cents: 10_000)
  end

  def rule(attrs)
    watch.alert_rules.new(attrs)
  end

  # --- percent_drop ---
  test "percent_drop valid with value_pct in (0,100]" do
    assert rule(kind: "percent_drop", value_pct: 25).valid?
    assert rule(kind: "percent_drop", value_pct: 100).valid?
    assert rule(kind: "percent_drop", value_pct: 0.5).valid?
  end

  test "percent_drop invalid outside (0,100] or with value_cents" do
    assert_not rule(kind: "percent_drop", value_pct: 0).valid?
    assert_not rule(kind: "percent_drop", value_pct: 100.01).valid?
    assert_not rule(kind: "percent_drop", value_pct: nil).valid?
    assert_not rule(kind: "percent_drop", value_pct: 25, value_cents: 100).valid?
  end

  # --- amount_drop / below_price ---
  test "amount_drop and below_price valid with positive value_cents" do
    assert rule(kind: "amount_drop", value_cents: 500).valid?
    assert rule(kind: "below_price", value_cents: 8000).valid?
  end

  test "amount_drop and below_price invalid with non-positive cents or with value_pct" do
    assert_not rule(kind: "amount_drop", value_cents: 0).valid?
    assert_not rule(kind: "below_price", value_cents: nil).valid?
    assert_not rule(kind: "below_price", value_cents: 8000, value_pct: 10).valid?
  end

  test "kind enum round-trips" do
    %w[percent_drop amount_drop below_price].each do |kind|
      r = AlertRule.new(kind: kind)
      assert_equal kind, r.kind
      assert r.public_send("#{kind}?")
    end
  end

  test "invalid kind raises on assignment" do
    assert_raises(ArgumentError) { AlertRule.new(kind: "nonsense") }
  end
end
