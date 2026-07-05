class Device < ApplicationRecord
  validates :expo_push_token, presence: true, uniqueness: true
end
