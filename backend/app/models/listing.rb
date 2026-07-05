class Listing < ApplicationRecord
  # product is optional: manual "by URL" watches have no barcode/product.
  belongs_to :product, optional: true
  belongs_to :store

  has_many :price_points, dependent: :destroy
  has_many :watches, dependent: :destroy

  enum :status, {
    active: "active",
    parse_failed: "parse_failed",
    blocked: "blocked",
    archived: "archived"
  }

  validates :url, presence: true
  validates :product_id, uniqueness: { scope: :store_id }, allow_nil: true

  def latest_price_point
    price_points.order(checked_at: :desc, id: :desc).first
  end

  # Display name: product name, else the manual display_name, else the URL host.
  def resolved_name
    product&.name.presence || display_name.presence || url_host
  end

  def url_host
    URI.parse(url).host
  rescue URI::InvalidURIError
    url
  end
end
