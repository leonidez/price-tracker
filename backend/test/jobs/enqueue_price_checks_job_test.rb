require "test_helper"

class EnqueuePriceChecksJobTest < ActiveJob::TestCase
  test "enqueues a check for active and parse_failed listings, skipping blocked/archived" do
    store = Store.create!(name: "Fake", slug: "fake", domain: "fake.test", adapter: "generic")
    build = lambda do |status, suffix|
      product = Product.create!(gtin13: "111111111111#{suffix}")
      Listing.create!(product: product, store: store, url: "https://fake.test/#{suffix}", status: status)
    end
    build.call("active", 1)
    build.call("parse_failed", 2)
    build.call("blocked", 3)
    build.call("archived", 4)

    expected = Listing.where(status: %w[active parse_failed]).count
    assert_operator expected, :>=, 2

    assert_enqueued_jobs expected, only: CheckPriceJob do
      EnqueuePriceChecksJob.perform_now
    end
  end
end

class RecurringConfigTest < ActiveSupport::TestCase
  test "recurring.yml schedules EnqueuePriceChecksJob every 6 hours" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    tasks = config.values.flat_map { |env| env.is_a?(Hash) ? env.values : [] }
    entry = tasks.find { |task| task.is_a?(Hash) && task["class"] == "EnqueuePriceChecksJob" }

    assert entry, "expected an EnqueuePriceChecksJob recurring task"
    assert_match(/6 hours/, entry["schedule"])
  end
end
