# Serializes a POST /resolutions response: the normalized product plus the
# adapter's resolution (echoed back by the client into POST /watches).
class ResolutionSerializer
  def initialize(gtin13, resolution)
    @gtin13 = gtin13
    @resolution = resolution
  end

  def as_json(*)
    {
      product: {
        gtin13: @gtin13,
        name: @resolution.title,
        image_url: @resolution.image_url
      },
      resolution: {
        url: @resolution.url,
        title: @resolution.title,
        image_url: @resolution.image_url,
        price_cents: @resolution.price_cents,
        currency: @resolution.currency,
        verified: @resolution.verified,
        store_ref: @resolution.store_ref || {}
      }
    }
  end
end
