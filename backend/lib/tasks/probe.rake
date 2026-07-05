# Live "smoke" probes against real store sites. MANUAL ONLY — never run in CI
# (store sites block datacenter IPs; run from a home IP). See docs/DESIGN.md.
namespace :probe do
  desc "Live Walmart resolve probe. Usage: bin/rails 'probe:walmart[0036000291452]'"
  task :walmart, [ :gtin13 ] => :environment do |_task, args|
    gtin13 = args[:gtin13]
    abort "usage: bin/rails 'probe:walmart[<gtin13>]'" if gtin13.blank?

    adapter = StoreAdapters.for(Store.find_by!(slug: "walmart"))
    resolution = adapter.resolve(gtin13: gtin13)
    pp resolution
  rescue StoreAdapters::ResolveFailed => e
    warn "resolve failed: #{e.code}"
  rescue Http::BlockedError => e
    warn "blocked (expected from a datacenter IP): #{e.message}"
  end
end
