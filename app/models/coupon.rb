class Coupon < ApplicationRecord
  belongs_to :restaurant
  has_and_belongs_to_many :tags

  # validation restaurant_id, presence: true
  # validation description, presence: true
  # validation quantity, presence: true
  # validation remaining, presence: true

  def as_json(options={})
    {
      id: id,
      description: description,
      quantity: quantity,
      remaining: remaining,
      expired: expired,
      expiration_time: expiration_time,
      restaurant_id: restaurant_id,
      created_at: created_at,
      updated_at: updated_at,
      restaurant: restaurant,
      tags: tags.to_a
    }
  end
end
