require "json"
require "bigdecimal"

module StoreAdapters
  # Target adapter. Target's site is client-rendered but feeds off the openly
  # accessible "RedSky" JSON API. RedSky supports pricing_store_id, giving the
  # price for a *specific physical store* — the best shelf-price source we have.
  #
  # RedSky is unofficial and WILL drift: endpoint templates live in the
  # constants below (edit them when Target changes), and the key/store id live
  # in stores.config (see backend/README.md for how to obtain them). An HTML
  # fallback exists for when RedSky fails.
  class Target < Base
    SEARCH_ENDPOINT = "https://redsky.target.com/redsky_aggregations/v1/web/plp_search_v2".freeze
    PDP_ENDPOINT = "https://redsky.target.com/redsky_aggregations/v1/web/pdp_client_v1".freeze
    HTML_SEARCH_URL = "https://www.target.com/s?searchTerm=%s".freeze
    PRODUCT_URL = "https://www.target.com/p/-/A-%s".freeze
    MAX_CANDIDATES = 5

    def resolve(gtin13:, hint: nil)
      ensure_config!

      [ upc_a_form(gtin13), gtin13 ].compact.each do |code|
        search_products(code).first(MAX_CANDIDATES).each do |candidate|
          resolution = verify_candidate(candidate, gtin13)
          return resolution if resolution
        end
      end

      html_fallback(gtin13) || raise(ResolveFailed.new(code: :not_found))
    end

    def check(listing)
      ensure_config!

      tcin = listing.store_ref.is_a?(Hash) ? listing.store_ref["tcin"] : nil
      if tcin.present?
        via_redsky = check_via_redsky(tcin)
        return via_redsky if via_redsky
      end

      check_via_html(listing) || raise(CheckFailed.new(reason: :parse_failed))
    end

    private

    def ensure_config!
      missing = %i[redsky_key store_id].select { |key| config[key].blank? }
      return if missing.empty?

      raise ConfigurationError,
            "Target store is missing config: #{missing.join(', ')} " \
            "(obtain them via browser devtools on target.com — see backend/README.md)"
    end

    def config
      store.adapter_config
    end

    def upc_a_form(gtin13)
      gtin13.start_with?("0") ? gtin13[1..] : nil
    end

    # --- RedSky search -> candidate TCINs ---------------------------------

    def search_products(code)
      body = redsky_get(SEARCH_ENDPOINT, key: config[:redsky_key], keyword: code, pricing_store_id: config[:store_id])
      products = body&.dig("data", "search", "products") || []
      products.filter_map { |product| candidate_from(product) }
    rescue Http::FetchError, Http::BlockedError
      []
    end

    def candidate_from(product)
      tcin = product["tcin"]
      return nil unless tcin

      item = product["item"] || {}
      { tcin: tcin.to_s, title: item.dig("product_description", "title"),
        image_url: item.dig("enrichment", "images", "primary_image_url"),
        buy_url: item.dig("enrichment", "buy_url") }
    end

    # Fetch the PDP and accept only if primary_barcode matches the scan.
    def verify_candidate(candidate, gtin13)
      product = pdp_product(candidate[:tcin])
      return nil unless product
      return nil unless verified_gtin?([ product.dig("item", "primary_barcode") ], gtin13)

      Resolution.new(
        url: candidate[:buy_url] || product.dig("item", "enrichment", "buy_url") || format(PRODUCT_URL, candidate[:tcin]),
        title: candidate[:title] || product.dig("item", "product_description", "title"),
        image_url: candidate[:image_url] || product.dig("item", "enrichment", "images", "primary_image_url"),
        price_cents: current_retail_cents(product),
        currency: "USD",
        store_ref: { "tcin" => candidate[:tcin] },
        verified: true
      )
    end

    def pdp_product(tcin)
      body = redsky_get(PDP_ENDPOINT, key: config[:redsky_key], tcin: tcin, pricing_store_id: config[:store_id])
      body&.dig("data", "product")
    rescue Http::FetchError, Http::BlockedError
      nil
    end

    def current_retail_cents(product)
      retail = product.dig("price", "current_retail")
      retail && (BigDecimal(retail.to_s) * 100).round
    end

    # --- checks -----------------------------------------------------------

    def check_via_redsky(tcin)
      product = pdp_product(tcin)
      return nil unless product

      cents = current_retail_cents(product)
      return nil unless cents

      CheckResult.new(price_cents: cents, currency: "USD", in_stock: in_stock?(product), source: "redsky")
    end

    def check_via_html(listing)
      response = fetch(listing.url)
      result = extract(response.body, response.final_url)
      return nil if result.nil? || result.price_cents.nil?

      CheckResult.new(price_cents: result.price_cents, currency: result.currency, in_stock: result.in_stock, source: result.method)
    end

    def in_stock?(product)
      status = product.dig("fulfillment", "is_out_of_stock_in_all_store_locations")
      status.nil? ? true : !status
    end

    # --- HTML fallback for resolve ---------------------------------------

    def html_fallback(gtin13)
      [ upc_a_form(gtin13), gtin13 ].compact.each do |code|
        response = fetch(format(HTML_SEARCH_URL, code))
        resolution = resolution_from_html(response.body)
        return resolution if resolution
      end
      nil
    end

    def resolution_from_html(html)
      doc = Nokogiri::HTML(html)
      link = doc.at_css('a[href*="/A-"]')
      return nil unless link

      tcin = link["href"][/A-(\d+)/, 1]
      Resolution.new(
        url: absolute(link["href"]), title: link.text.strip.presence, image_url: nil,
        price_cents: nil, currency: "USD", store_ref: { "tcin" => tcin }.compact, verified: false
      )
    end

    # --- shared -----------------------------------------------------------

    def redsky_get(endpoint, params)
      response = fetch("#{endpoint}?#{params.to_query}")
      JSON.parse(response.body)
    rescue JSON::ParserError
      nil
    end

    def absolute(url)
      url.start_with?("http") ? url : "https://www.target.com#{url}"
    end
  end
end
