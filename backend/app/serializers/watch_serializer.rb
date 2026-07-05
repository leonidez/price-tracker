# Serializes a watch for the mobile app. `detailed: true` adds the price
# history and recent notifications (GET /watches/:id). See docs/API.md.
class WatchSerializer
  SPARKLINE_LIMIT = 30
  HISTORY_LIMIT = 90
  NOTIFICATION_LIMIT = 10

  def initialize(watch, detailed: false)
    @watch = watch
    @listing = watch.listing
    @detailed = detailed
  end

  def as_json(*)
    base = {
      id: @watch.id,
      active: @watch.active,
      armed: @watch.armed,
      baseline_price_cents: @watch.baseline_price_cents,
      product: product_json,
      store: store_json,
      listing: listing_json,
      latest_price: latest_price_json,
      rules: rules_json,
      sparkline: sparkline
    }
    return base unless @detailed

    base.merge(price_points: price_points_json, notifications: notifications_json)
  end

  private

  def product_json
    product = @listing.product
    { name: @listing.resolved_name, image_url: product&.image_url, gtin13: product&.gtin13 }
  end

  def store_json
    { slug: @listing.store.slug, name: @listing.store.name }
  end

  def listing_json
    { url: @listing.url, status: @listing.status, display_name: @listing.display_name }
  end

  def latest_price_json
    point = @listing.latest_price_point
    return nil unless point

    { price_cents: point.price_cents, currency: point.currency, in_stock: point.in_stock, checked_at: point.checked_at }
  end

  def rules_json
    @watch.alert_rules.map do |rule|
      { kind: rule.kind, value_cents: rule.value_cents, value_pct: rule.value_pct&.to_f }
    end
  end

  def sparkline
    @listing.price_points.order(checked_at: :desc, id: :desc).limit(SPARKLINE_LIMIT).pluck(:price_cents).reverse
  end

  def price_points_json
    @listing.price_points.order(checked_at: :desc, id: :desc).limit(HISTORY_LIMIT).map do |point|
      { price_cents: point.price_cents, in_stock: point.in_stock, checked_at: point.checked_at }
    end
  end

  def notifications_json
    @watch.notifications.order(id: :desc).limit(NOTIFICATION_LIMIT).map do |notification|
      { kind: notification.kind, notified_price_cents: notification.notified_price_cents, sent_at: notification.sent_at }
    end
  end
end
