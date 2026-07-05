class Store < ApplicationRecord
  has_many :listings, dependent: :destroy

  validates :name, :adapter, presence: true
  validates :slug, presence: true, uniqueness: true
  # domain is null: false at the DB level but may be blank (the generic "by URL" store).

  # Config with symbol keys (adapters read e.g. config[:redsky_key]).
  def adapter_config
    (config || {}).symbolize_keys
  end
end
