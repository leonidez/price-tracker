require "test_helper"

class WatchTest < ActiveSupport::TestCase
  def watch
    @watch ||= listings(:cola_walmart).watches.create!(baseline_price_cents: 10_000)
  end

  test "requires baseline_price_cents" do
    assert_not Watch.new(listing: listings(:cola_walmart)).valid?
  end

  test "last_price_alert returns the most recent price_alert notification" do
    watch.notifications.create!(kind: "parse_failure")
    watch.notifications.create!(kind: "price_alert", notified_price_cents: 9000)
    latest = watch.notifications.create!(kind: "price_alert", notified_price_cents: 8000)
    assert_equal latest, watch.last_price_alert
  end

  test "last_price_alert is nil when there are no price alerts" do
    watch.notifications.create!(kind: "parse_failure")
    assert_nil watch.last_price_alert
  end

  test "destroying a watch destroys alert_rules and notifications" do
    watch.alert_rules.create!(kind: "below_price", value_cents: 5000)
    watch.notifications.create!(kind: "price_alert", notified_price_cents: 4000)
    assert_difference([ "AlertRule.count", "Notification.count" ], -1) do
      watch.destroy
    end
  end
end
