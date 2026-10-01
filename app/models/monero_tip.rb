# frozen_string_literal: true

class MoneroTip < ActiveRecord::Base
  ATOMIC_UNITS = 1_000_000_000_000

  belongs_to :payee, class_name: "User"
  belongs_to :tipper, class_name: "User", optional: true

  scope :confirmed, -> { where(confirmed: true) }

  def amount_xmr
    amount.to_d / ATOMIC_UNITS
  end
end
