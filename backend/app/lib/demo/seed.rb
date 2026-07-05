module Demo
  # Idempotent demo data for exercising the mobile UI in dev: a few generic-store
  # watches with 30 points of fabricated history covering every card state
  # (on-sale, steady, parse_failed, paused/inactive).
  module Seed
    HISTORY_POINTS = 30

    WATCHES = [
      { name: "Demo — On Sale Blender", url: "https://example.com/demo/blender",
        baseline_cents: 9_999, current_cents: 6_999, status: "active", active: true },
      { name: "Demo — Steady Headphones", url: "https://example.com/demo/headphones",
        baseline_cents: 14_999, current_cents: 14_899, status: "active", active: true },
      { name: "Demo — Unreadable Lamp", url: "https://example.com/demo/lamp",
        baseline_cents: 4_999, current_cents: 4_599, status: "parse_failed", active: true },
      { name: "Demo — Paused Kettle", url: "https://example.com/demo/kettle",
        baseline_cents: 3_999, current_cents: 2_999, status: "active", active: false }
    ].freeze

    module_function

    def call
      store = Store.find_by!(slug: "generic")
      WATCHES.map { |attrs| build_watch(store, attrs) }
    end

    def build_watch(store, attrs)
      listing = Listing.find_or_initialize_by(store: store, url: attrs[:url])
      listing.update!(display_name: attrs[:name], status: attrs[:status], currency: "USD")

      rebuild_history(listing, attrs[:baseline_cents], attrs[:current_cents])

      watch = Watch.find_or_initialize_by(listing: listing)
      watch.update!(baseline_price_cents: attrs[:baseline_cents], active: attrs[:active], armed: true)
      watch.alert_rules.create!(kind: "percent_drop", value_pct: 20) if watch.alert_rules.empty?
      watch
    end

    # Linear interpolation baseline -> current across HISTORY_POINTS days.
    def rebuild_history(listing, baseline_cents, current_cents)
      listing.price_points.delete_all
      last_index = HISTORY_POINTS - 1
      HISTORY_POINTS.times do |index|
        fraction = index.to_f / last_index
        cents = (baseline_cents + (current_cents - baseline_cents) * fraction).round
        listing.price_points.create!(
          price_cents: cents, currency: "USD", in_stock: true,
          checked_at: (last_index - index).days.ago, source: "demo"
        )
      end
    end
  end
end
