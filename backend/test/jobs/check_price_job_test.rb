require "test_helper"

class CheckPriceJobTest < ActiveJob::TestCase
  setup do
    StoreAdapters.register("fake", FakeAdapter)
    @store = Store.create!(name: "Fake", slug: "fake", domain: "fake.test", adapter: "fake")
    @product = Product.create!(gtin13: "0000000000000")
    @listing = Listing.create!(product: @product, store: @store, url: "https://fake.test/p", status: "active")
  end

  teardown do
    FakeAdapter.reset!
    StoreAdapters.reset_registry!
  end

  def succeed_with(cents)
    FakeAdapter.check_handler = lambda do |_listing|
      StoreAdapters::CheckResult.new(price_cents: cents, currency: "USD", in_stock: true, source: "fake")
    end
  end

  def fail_with(error)
    FakeAdapter.check_handler = ->(_listing) { raise error }
  end

  test "success creates a price point and resets consecutive_failures" do
    @listing.update!(consecutive_failures: 2)
    succeed_with(1_234)

    assert_difference("PricePoint.count", 1) { CheckPriceJob.perform_now(@listing) }

    @listing.reload
    assert_equal 0, @listing.consecutive_failures
    assert_not_nil @listing.last_checked_at
    assert_equal 1_234, @listing.latest_price_point.price_cents
    assert_equal "fake", @listing.latest_price_point.source
  end

  test "success evaluates alerts and creates a price_alert notification" do
    watch = @listing.watches.create!(baseline_price_cents: 5_000, armed: true, active: true)
    watch.alert_rules.create!(kind: "below_price", value_cents: 2_000)
    succeed_with(1_500)

    assert_difference("Notification.where(kind: 'price_alert').count", 1) do
      CheckPriceJob.perform_now(@listing)
    end
  end

  test "three consecutive parse failures transition to parse_failed with one notification per active watch" do
    active_a = @listing.watches.create!(baseline_price_cents: 5_000, active: true)
    active_b = @listing.watches.create!(baseline_price_cents: 5_000, active: true)
    @listing.watches.create!(baseline_price_cents: 5_000, active: false)
    fail_with(StoreAdapters::CheckFailed.new(reason: :parse_failed))

    CheckPriceJob.perform_now(@listing)
    assert @listing.reload.active?
    CheckPriceJob.perform_now(@listing)
    assert @listing.reload.active?

    assert_difference("Notification.where(kind: 'parse_failure').count", 2) do
      CheckPriceJob.perform_now(@listing)
    end
    @listing.reload
    assert @listing.parse_failed?
    assert_equal 3, @listing.consecutive_failures
    assert_equal [ active_a.id, active_b.id ].sort, Notification.where(kind: "parse_failure").pluck(:watch_id).sort

    # A 4th failure must NOT create another notification (transition-only).
    assert_no_difference("Notification.count") { CheckPriceJob.perform_now(@listing) }
  end

  test "three consecutive blocks transition to blocked" do
    fail_with(Http::BlockedError.new("robot?"))
    3.times { CheckPriceJob.perform_now(@listing) }
    assert @listing.reload.blocked?
    assert_equal 3, @listing.consecutive_failures
  end

  test "a successful check recovers a parse_failed listing to active" do
    @listing.update!(status: "parse_failed", consecutive_failures: 4)
    succeed_with(999)
    CheckPriceJob.perform_now(@listing)
    @listing.reload
    assert @listing.active?
    assert_equal 0, @listing.consecutive_failures
  end

  test "does not enqueue a push when SendPushJob is undefined" do
    assert_not defined?(SendPushJob), "guard assumption: SendPushJob is not defined until #11"
    succeed_with(1_000)
    assert_nothing_raised { CheckPriceJob.perform_now(@listing) }
  end
end
