class Watch < ApplicationRecord
  belongs_to :listing

  has_many :alert_rules, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :baseline_price_cents, presence: true, numericality: { only_integer: true }

  # Most recent price_alert notification for this watch.
  def last_price_alert
    notifications.where(kind: "price_alert").order(id: :desc).first
  end
end
