require "json"
require "bigdecimal"

module StoreAdapters
  # Walmart adapter: resolve raw UPCs via site search, price via the product
  # page's JSON-LD or Next.js __NEXT_DATA__ blob. Walmart has the most
  # aggressive bot-detection of our stores ("Robot or human?" challenge), so
  # every fetch carries a challenge marker and blocks surface as
  # Http::BlockedError. Ops-wise we run from a home IP at low frequency
  # (see docs/DESIGN.md § Operational constraints).
  #
  # NOTE: issue #6's body is truncated on GitHub mid-spec; this implements the
  # visible spec + docs/DESIGN.md. Live behavior is human-verified (probe task).
  class Walmart < Base
    BASE_URL = "https://www.walmart.com".freeze
    SEARCH_URL = "https://www.walmart.com/search?q=%s".freeze
    CHALLENGE = /Robot or human|px-captcha|Verify your identity|Are you a human/i
    MAX_CANDIDATES = 5
    GTIN_KEYS = %w[upc gtin gtin13 gtin12 gtin14].freeze

    def resolve(gtin13:, hint: nil)
      candidates = search_candidates(gtin13)
      raise ResolveFailed.new(code: :not_found) if candidates.empty?

      candidates.first(MAX_CANDIDATES).each do |candidate|
        resolution = verify_candidate(candidate, gtin13)
        return resolution if resolution
      end

      raise ResolveFailed.new(code: :not_found)
    end

    def check(listing)
      response = fetch(listing.url, blocked_if: CHALLENGE)
      product = extract_product(response.body, response.final_url)
      raise CheckFailed.new(reason: :parse_failed) unless product && product[:price_cents]

      CheckResult.new(
        price_cents: product[:price_cents],
        currency: product[:currency] || "USD",
        in_stock: product.fetch(:in_stock, true),
        source: product[:source]
      )
    end

    private

    # Try the 12-digit UPC-A form (strip the GTIN-13 leading zero) first, then
    # the 13-digit form. First form to return candidates wins.
    def search_candidates(gtin13)
      [ upc_a_form(gtin13), gtin13 ].compact.each do |code|
        response = fetch(format(SEARCH_URL, code), blocked_if: CHALLENGE)
        candidates = parse_search(response.body)
        return candidates if candidates.any?
      end
      []
    end

    def upc_a_form(gtin13)
      gtin13.start_with?("0") ? gtin13[1..] : nil
    end

    # Fetch a candidate product page and accept it only if a GTIN on the page
    # matches the scan (absorbs UPC-A vs EAN-13 format differences).
    def verify_candidate(candidate, gtin13)
      response = fetch(candidate[:url], blocked_if: CHALLENGE)
      product = extract_product(response.body, response.final_url)
      return nil unless product && verified_gtin?(product[:gtins], gtin13)

      Resolution.new(
        url: candidate[:url],
        title: candidate[:title] || product[:title],
        image_url: candidate[:image_url] || product[:image_url],
        price_cents: product[:price_cents],
        currency: product[:currency] || "USD",
        store_ref: candidate[:store_ref] || {},
        verified: true
      )
    end

    # --- search page -> candidate URLs ------------------------------------

    def parse_search(html)
      doc = Nokogiri::HTML(html)
      candidates = from_next_data_search(doc)
      candidates.any? ? candidates : from_anchor_links(doc)
    end

    def from_next_data_search(doc)
      data = next_data(doc)
      return [] unless data

      results = []
      deep_each_hash(data) do |hash|
        url = hash["canonicalUrl"] || hash["productPageUrl"]
        next unless url.is_a?(String) && url.include?("/ip/")

        results << {
          url: absolute(url),
          title: hash["name"] || hash["title"],
          image_url: hash.dig("imageInfo", "thumbnailUrl") || hash["image"],
          store_ref: hash["usItemId"] ? { "us_item_id" => hash["usItemId"].to_s } : {}
        }
      end
      results.uniq { |candidate| candidate[:url] }
    end

    def from_anchor_links(doc)
      doc.css('a[href*="/ip/"]').map do |anchor|
        { url: absolute(anchor["href"]), title: anchor.text.strip.presence, image_url: nil, store_ref: {} }
      end.uniq { |candidate| candidate[:url] }
    end

    # --- product page -> price + gtins ------------------------------------

    # Prefer the generic ladder (JSON-LD/meta); fall back to __NEXT_DATA__.
    # gtins are collected from both regardless of which priced the page.
    def extract_product(html, url)
      doc = Nokogiri::HTML(html)
      ladder = PriceExtractor.call(html: html, url: url)
      next_data_product = next_data_product(doc)

      gtins = ((ladder&.gtins || []) + (next_data_product&.dig(:gtins) || [])).uniq
      priced = priced_result(ladder, next_data_product)
      return nil if priced.nil? && gtins.empty?

      (priced || {}).merge(
        gtins: gtins,
        title: priced&.dig(:title) || next_data_product&.dig(:title),
        image_url: priced&.dig(:image_url) || next_data_product&.dig(:image_url)
      )
    end

    def priced_result(ladder, next_data_product)
      if ladder&.price_cents
        { price_cents: ladder.price_cents, currency: ladder.currency, in_stock: ladder.in_stock, source: ladder.method }
      elsif next_data_product && next_data_product[:price_cents]
        next_data_product.merge(source: "next_data")
      end
    end

    def next_data_product(doc)
      data = next_data(doc)
      return nil unless data

      product = deep_find(data) { |hash| hash.key?("priceInfo") || hash.key?("currentPrice") }
      price_hash = product && (product.dig("priceInfo", "currentPrice") || product["currentPrice"])
      price = price_hash && (price_hash["price"] || price_hash["priceString"])
      gtins = collect_next_data_gtins(data)
      return nil unless price || gtins.any?

      {
        price_cents: price ? (BigDecimal(price.to_s.gsub(/[^\d.]/, "")) * 100).round : nil,
        currency: price_hash&.dig("currencyUnit") || "USD",
        in_stock: in_stock?(product),
        gtins: gtins,
        title: product&.dig("name"),
        image_url: product&.dig("imageInfo", "thumbnailUrl")
      }
    end

    def in_stock?(product)
      status = product && (product["availabilityStatus"] || product["availability"])
      return true if status.nil?

      !status.to_s.upcase.include?("OUT")
    end

    def collect_next_data_gtins(data)
      gtins = []
      deep_each_hash(data) do |hash|
        GTIN_KEYS.each do |key|
          value = hash[key]
          gtins << value.to_s if value.is_a?(String) || value.is_a?(Integer)
        end
      end
      gtins.uniq
    end

    # --- shared helpers ---------------------------------------------------

    def next_data(doc)
      node = doc.at_css("script#__NEXT_DATA__")
      return nil unless node

      JSON.parse(node.text)
    rescue JSON::ParserError
      nil
    end

    def deep_find(data, &block)
      case data
      when Hash
        return data if block.call(data)

        data.each_value { |value| (found = deep_find(value, &block)) and return found }
        nil
      when Array
        data.each { |value| (found = deep_find(value, &block)) and return found }
        nil
      end
    end

    def deep_each_hash(data, &block)
      case data
      when Hash
        block.call(data)
        data.each_value { |value| deep_each_hash(value, &block) }
      when Array
        data.each { |value| deep_each_hash(value, &block) }
      end
    end

    def absolute(url)
      url.start_with?("http") ? url : "#{BASE_URL}#{url}"
    end
  end
end
