class Notification < ApplicationRecord
  belongs_to :watch
  belongs_to :price_point, optional: true

  enum :kind, {
    price_alert: "price_alert",
    parse_failure: "parse_failure"
  }

  validates :kind, presence: true
end
