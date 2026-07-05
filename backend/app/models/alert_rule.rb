class AlertRule < ApplicationRecord
  belongs_to :watch

  enum :kind, {
    percent_drop: "percent_drop",
    amount_drop: "amount_drop",
    below_price: "below_price"
  }

  validates :kind, presence: true
  validate :value_matches_kind

  private

  # Kind-specific value rules: the used column must be valid; the other must be nil.
  def value_matches_kind
    case kind
    when "percent_drop"
      unless value_pct && value_pct > 0 && value_pct <= 100
        errors.add(:value_pct, "must be in (0, 100]")
      end
      errors.add(:value_cents, "must be blank for percent_drop") unless value_cents.nil?
    when "amount_drop", "below_price"
      errors.add(:value_cents, "must be greater than 0") unless value_cents && value_cents > 0
      errors.add(:value_pct, "must be blank for #{kind}") unless value_pct.nil?
    end
  end
end
