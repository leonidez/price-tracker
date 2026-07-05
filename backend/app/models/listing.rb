class Listing < ApplicationRecord
  belongs_to :product
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
  validates :product_id, uniqueness: { scope: :store_id }

  def latest_price_point
    price_points.order(checked_at: :desc, id: :desc).first
  end
end
