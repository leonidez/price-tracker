require "nokogiri"
require "json"

# The generic price-extraction ladder (docs/DESIGN.md § Store adapters).
# First hit wins: JSON-LD -> meta/microdata -> per-store CSS selector -> nil.
#
# `gtins` collects every gtin12/gtin13/gtin found in JSON-LD regardless of which
# tier priced the page (adapters use it to verify a candidate matches the scan).
module PriceExtractor
  Result = Data.define(:price_cents, :currency, :in_stock, :method, :gtins)

  module_function

  def call(html:, url: nil, selector_config: nil)
    doc = Nokogiri::HTML(html.to_s)
    ld_objects = json_ld_objects(doc)
    gtins = collect_gtins(ld_objects)

    from_json_ld(ld_objects, gtins) ||
      from_meta(doc, gtins) ||
      from_selector(doc, selector_config, gtins)
  end

  # --- Tier 1: JSON-LD ---------------------------------------------------

  def from_json_ld(ld_objects, gtins)
    product = ld_objects.find { |obj| types(obj).include?("Product") }
    return nil unless product

    offer = pick_offer(product["offers"])
    return nil unless offer

    price = offer_price(offer)
    return nil if price.nil?

    currency = offer["priceCurrency"] || "USD"
    Result.new(
      price_cents: to_cents(price),
      currency: currency,
      in_stock: availability_in_stock(offer["availability"]),
      method: "jsonld",
      gtins: gtins
    )
  end

  def pick_offer(offers)
    case offers
    when Hash then offers
    when Array then offers.compact.first
    end
  end

  # Offer / AggregateOffer / array-of-offers -> a single price (dollars).
  def offer_price(offer)
    if offer["@type"].to_s == "AggregateOffer" || offer.key?("lowPrice")
      offer["lowPrice"]
    else
      offer["price"]
    end
  end

  def availability_in_stock(availability)
    return true if availability.nil?

    text = availability.to_s
    return false if text.include?("OutOfStock")
    true
  end

  # --- Tier 2: meta / microdata -----------------------------------------

  def from_meta(doc, gtins)
    amount = meta_content(doc, 'meta[property="product:price:amount"]')
    if amount
      currency = meta_content(doc, 'meta[property="product:price:currency"]') || "USD"
      return build(amount, currency, "meta", gtins)
    end

    itemprop = meta_content(doc, 'meta[itemprop="price"]') ||
               doc.at_css('[itemprop="price"]')&.[]("content")
    return build(itemprop, nil, "meta", gtins) if itemprop

    nil
  end

  def meta_content(doc, selector)
    node = doc.at_css(selector)
    value = node&.[]("content")
    value if value.present?
  end

  # --- Tier 3: CSS selector from stores.config --------------------------

  def from_selector(doc, selector_config, gtins)
    config = symbolize(selector_config)
    selector = config[:price]
    return nil if selector.blank?

    node = doc.at_css(selector)
    return nil unless node

    build(node.text, config[:currency], "selector", gtins)
  end

  # --- shared -----------------------------------------------------------

  # Build a Result from a raw price string via the money parser.
  def build(raw_price, currency, method, gtins)
    parsed = MoneyParser.parse(raw_price)
    return nil if parsed.nil?

    cents, parsed_currency = parsed
    Result.new(
      price_cents: cents,
      currency: currency.presence || parsed_currency,
      in_stock: true,
      method: method,
      gtins: gtins
    )
  end

  def to_cents(price)
    cents, = MoneyParser.parse(price.to_s)
    cents
  end

  def json_ld_objects(doc)
    doc.css('script[type="application/ld+json"]').flat_map do |script|
      parse_json(script.text)
    end.compact
  end

  # Flatten top-level objects, arrays, and @graph into a flat list of hashes.
  def parse_json(text)
    data = JSON.parse(text)
    flatten_ld(data)
  rescue JSON::ParserError
    []
  end

  def flatten_ld(data)
    case data
    when Array then data.flat_map { |item| flatten_ld(item) }
    when Hash
      graph = data["@graph"]
      graph.is_a?(Array) ? graph.flat_map { |item| flatten_ld(item) } : [ data ]
    else
      []
    end
  end

  def types(obj)
    Array(obj["@type"]).map(&:to_s)
  end

  def collect_gtins(ld_objects)
    keys = %w[gtin13 gtin12 gtin gtin8 gtin14]
    ld_objects.flat_map do |obj|
      offers = Array(obj["offers"].is_a?(Hash) ? [ obj["offers"] ] : obj["offers"])
      ([ obj ] + offers).flat_map do |source|
        next [] unless source.is_a?(Hash)

        keys.filter_map { |key| source[key]&.to_s }
      end
    end.uniq
  end

  def symbolize(config)
    return {} if config.nil?

    config.respond_to?(:symbolize_keys) ? config.symbolize_keys : config
  end
end
