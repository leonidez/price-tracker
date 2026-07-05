module StoreAdapters
  # The paste-any-URL fallback: check-only, works on any store's product page.
  class Generic < Base
    # Barcode resolution isn't possible for arbitrary stores.
    def resolve(gtin13:, hint: nil)
      raise ResolveFailed.new(code: :unsupported)
    end

    # Fetch the listing URL and run the extraction ladder. A page that clearly
    # exists but yields no price is a parse failure (callers in #9 decide about
    # failure counting). Http::BlockedError / Http::FetchError bubble up.
    def check(listing)
      response = fetch(listing.url)
      result = extract(response.body, response.final_url)

      raise CheckFailed.new(reason: :parse_failed) if result.nil? || result.price_cents.nil?

      CheckResult.new(
        price_cents: result.price_cents,
        currency: result.currency,
        in_stock: result.in_stock,
        source: result.method
      )
    end
  end
end
