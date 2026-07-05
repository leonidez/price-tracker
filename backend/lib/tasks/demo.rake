namespace :demo do
  desc "Create idempotent demo watches (generic store) with fabricated history for dev UI"
  task seed: :environment do
    watches = Demo::Seed.call
    puts "Seeded #{watches.size} demo watch(es): #{watches.map { |w| w.listing.display_name }.join(', ')}"
  end
end
