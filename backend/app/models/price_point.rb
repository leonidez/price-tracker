class PricePoint < ApplicationRecord
  belongs_to :listing

  has_many :notifications, dependent: :nullify

  validates :price_cents, presence: true, numericality: { only_integer: true }
  validates :currency, presence: true
  validates :checked_at, presence: true
end
