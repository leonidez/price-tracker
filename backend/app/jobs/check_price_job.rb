# Check one listing's price, record history, evaluate alerts, and handle
# failures honestly (docs/DESIGN.md: a tracker that silently stops checking is
# worse than one that admits it). No in-job retries — the schedule is the retry.
#
# TODO: limit concurrency per store domain once we outgrow jitter. Solid Queue
# supports `limits_concurrency key: ->(listing) { listing.store_id }`; for v1
# volumes the recurring job's jitter is sufficient.
class CheckPriceJob < ApplicationJob
  queue_as :default

  FAILURE_THRESHOLD = 3

  def perform(listing)
    result = StoreAdapters.for(listing.store).check(listing)
    record_success(listing, result)
  rescue Http::BlockedError
    record_failure(listing, transition_to: :blocked)
  rescue StoreAdapters::CheckFailed, Http::FetchError
    record_failure(listing, transition_to: :parse_failed)
  end

  private

  def record_success(listing, result)
    price_point = listing.price_points.create!(
      price_cents: result.price_cents,
      currency: result.currency,
      in_stock: result.in_stock,
      checked_at: Time.current,
      source: result.source
    )
    listing.status = :active if listing.parse_failed?
    listing.update!(last_checked_at: Time.current, consecutive_failures: 0)

    Alerts::Evaluate.call(price_point: price_point).each { |notification| enqueue_push(notification) }
  end

  def record_failure(listing, transition_to:)
    old_status = listing.status
    listing.consecutive_failures += 1
    listing.last_checked_at = Time.current
    listing.status = transition_to.to_s if listing.consecutive_failures >= FAILURE_THRESHOLD
    listing.save!

    notify_parse_failure(listing) if listing.status != old_status
  end

  # One parse_failure notification per active watch, only on the transition.
  def notify_parse_failure(listing)
    listing.watches.where(active: true).find_each do |watch|
      notification = watch.notifications.create!(kind: "parse_failure")
      enqueue_push(notification)
    end
  end

  def enqueue_push(notification)
    SendPushJob.perform_later(notification)
  end
end
