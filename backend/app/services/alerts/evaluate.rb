module Alerts
  # Decide whether a new price point should notify (docs/DESIGN.md § Alert
  # semantics). Rules within a watch are OR'd; alerts fire on the false->true
  # transition and re-fire only on a further drop or after re-arming. Creates
  # Notification rows only — no push/HTTP here.
  class Evaluate
    def self.call(price_point:)
      new(price_point).call
    end

    # Predicate for one rule (exposed for unit tests). Exact threshold equality
    # counts as triggered.
    def self.rule_triggered?(rule, baseline_price_cents:, price_cents:)
      case rule.kind
      when "below_price"
        price_cents <= rule.value_cents
      when "amount_drop"
        baseline_price_cents - price_cents >= rule.value_cents
      when "percent_drop"
        threshold = (baseline_price_cents * (100 - rule.value_pct) / 100.0).round
        price_cents <= threshold
      else
        false
      end
    end

    def initialize(price_point)
      @price_point = price_point
    end

    def call
      return [] unless @price_point.in_stock?

      notifications = []
      @price_point.listing.watches.where(active: true).find_each do |watch|
        notification = evaluate_watch(watch)
        notifications << notification if notification
      end
      notifications
    end

    private

    def evaluate_watch(watch)
      unless triggered?(watch)
        watch.update!(armed: true)
        return nil
      end

      notify(watch) if notify?(watch)
    end

    def triggered?(watch)
      price_cents = @price_point.price_cents
      watch.alert_rules.any? do |rule|
        self.class.rule_triggered?(rule, baseline_price_cents: watch.baseline_price_cents, price_cents: price_cents)
      end
    end

    # Notify only on the false->true transition (armed), or when this price is
    # below the price we last alerted about (a further drop).
    def notify?(watch)
      last = watch.last_price_alert
      watch.armed? || last.nil? || @price_point.price_cents < last.notified_price_cents
    end

    def notify(watch)
      notification = watch.notifications.create!(
        kind: "price_alert",
        price_point: @price_point,
        notified_price_cents: @price_point.price_cents
      )
      watch.update!(armed: false)
      notification
    end
  end
end
