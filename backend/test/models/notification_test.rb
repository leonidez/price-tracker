require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  def watch
    @watch ||= listings(:cola_walmart).watches.create!(baseline_price_cents: 10_000)
  end

  test "price_alert notification is valid" do
    assert watch.notifications.new(kind: "price_alert", notified_price_cents: 9000).valid?
  end

  test "parse_failure notification is valid without a price_point" do
    assert watch.notifications.new(kind: "parse_failure").valid?
  end

  test "kind enum round-trips" do
    %w[price_alert parse_failure].each do |kind|
      n = Notification.new(kind: kind)
      assert_equal kind, n.kind
      assert n.public_send("#{kind}?")
    end
  end
end
