class Product < ApplicationRecord
  has_many :listings, dependent: :destroy

  validates :gtin13,
            presence: true,
            uniqueness: true,
            format: { with: /\A\d{13}\z/, message: "must be 13 digits" }
end
