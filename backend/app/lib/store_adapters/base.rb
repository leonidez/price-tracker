module StoreAdapters
  # Base adapter. Subclasses implement #resolve and #check; shared helpers wrap
  # the store-agnostic building blocks from issue #4.
  class Base
    attr_reader :store

    def initialize(store)
      @store = store
    end

    # gtin13:, hint: -> Resolution or nil. Raise ResolveFailed on hard failures.
    def resolve(gtin13:, hint: nil)
      raise NotImplementedError, "#{self.class}#resolve"
    end

    # listing -> CheckResult. Raise CheckFailed (reason:) or let Http::BlockedError bubble.
    def check(listing)
      raise NotImplementedError, "#{self.class}#check"
    end

    private

    def fetch(url, blocked_if: nil)
      Http::Fetcher.get(url, blocked_if: blocked_if)
    end

    # Run the extraction ladder with this store's configured CSS selectors.
    def extract(html, url)
      PriceExtractor.call(html: html, url: url, selector_config: selector_config)
    end

    def selector_config
      store.adapter_config[:selectors]
    end

    # True when any GTIN found on the page normalizes to the scanned code.
    # Absorbs UPC-A (12) vs EAN-13 (13) format differences.
    def verified_gtin?(page_gtins, gtin13)
      scanned = Gtin.normalize(gtin13)
      return false unless scanned

      Array(page_gtins).any? { |candidate| Gtin.normalize(candidate) == scanned }
    end
  end
end
