# Notification copy for Expo pushes, kept in one place with unit tests.
# Money is formatted from integer cents; never floats in storage.
module PushCopy
  CURRENCY_SYMBOLS = { "USD" => "$", "EUR" => "€", "GBP" => "£" }.freeze

  module_function

  def title(notification)
    notification.parse_failure? ? parse_failure_title(notification) : price_alert_title(notification)
  end

  def body(notification)
    notification.parse_failure? ? parse_failure_body(notification) : price_alert_body(notification)
  end

  def price_alert_title(notification)
    "📉 #{product_name(notification)} — #{format_cents(notification.notified_price_cents, currency(notification))}"
  end

  def price_alert_body(notification)
    price = notification.notified_price_cents
    baseline = notification.watch.baseline_price_cents
    unit = currency(notification)
    "Now #{format_cents(price, unit)} at #{store_name(notification)} — " \
      "#{percent_off(baseline, price)}% / #{format_cents(baseline - price, unit)} below your #{format_cents(baseline, unit)}"
  end

  def parse_failure_title(notification)
    "⚠️ Can't check #{product_name(notification)}"
  end

  def parse_failure_body(notification)
    "#{store_name(notification)} page stopped returning a price. Open the app to re-pair it."
  end

  def format_cents(cents, currency = "USD")
    symbol = CURRENCY_SYMBOLS.fetch(currency, "$")
    "#{symbol}#{format('%.2f', cents.to_i / 100.0)}"
  end

  def percent_off(baseline, price)
    return 0 if baseline.to_i <= 0

    (((baseline - price).to_f / baseline) * 100).round
  end

  def product_name(notification)
    notification.watch.listing.resolved_name
  end

  def store_name(notification)
    notification.watch.listing.store.name
  end

  def currency(notification)
    notification.price_point&.currency || notification.watch.listing.currency || "USD"
  end
end
