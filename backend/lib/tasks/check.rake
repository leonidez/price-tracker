namespace :check do
  desc "Run one price check inline and print the result. Usage: bin/rails 'check:listing[<id>]'"
  task :listing, [ :id ] => :environment do |_task, args|
    listing = Listing.find(args.fetch(:id))
    CheckPriceJob.perform_now(listing)
    listing.reload
    point = listing.latest_price_point
    puts "Listing ##{listing.id} [#{listing.status}] failures=#{listing.consecutive_failures}"
    if point
      puts "  latest: #{point.price_cents} #{point.currency} in_stock=#{point.in_stock} source=#{point.source}"
    else
      puts "  no price points yet"
    end
  end
end
