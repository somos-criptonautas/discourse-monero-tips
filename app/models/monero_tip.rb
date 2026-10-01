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

# == Schema Information
#
# Table name: monero_tips
#
#  id            :bigint           not null, primary key
#  address       :string           not null
#  amount        :bigint           not null
#  confirmations :integer          default(0), not null
#  confirmed     :boolean          default(FALSE), not null
#  received_at   :datetime         not null
#  txid          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  payee_id      :integer          not null
#  tipper_id     :integer
#
# Indexes
#
#  index_monero_tips_on_payee_id_and_txid_and_address  (payee_id,txid,address) UNIQUE
#  index_monero_tips_on_tipper_id                      (tipper_id)
#
