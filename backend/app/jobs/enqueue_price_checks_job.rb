# Recurring fan-out (config/recurring.yml, every 6 hours): schedule a jittered
# price check for every checkable listing. Jitter spreads load so we don't burst
# against one domain. Blocked/archived listings are skipped.
class EnqueuePriceChecksJob < ApplicationJob
  queue_as :default

  MAX_JITTER = 30.minutes

  def perform
    Listing.where(status: [ :active, :parse_failed ]).find_each do |listing|
      CheckPriceJob.set(wait: rand(0..MAX_JITTER.to_i).seconds).perform_later(listing)
    end
  end
end
