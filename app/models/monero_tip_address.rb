# frozen_string_literal: true

# One subaddress per (payee, tipper) pair. That is what makes a tip
# attributable: Monero transfers carry no sender, but they do say which
# subaddress received them.
class MoneroTipAddress < ActiveRecord::Base
  belongs_to :payee, class_name: "User"
  belongs_to :tipper, class_name: "User"
end

# == Schema Information
#
# Table name: monero_tip_addresses
#
#  id            :bigint           not null, primary key
#  address       :string           not null
#  address_index :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  payee_id      :integer          not null
#  tipper_id     :integer          not null
#
# Indexes
#
#  index_monero_tip_addresses_on_address                 (address) UNIQUE
#  index_monero_tip_addresses_on_payee_id_and_tipper_id  (payee_id,tipper_id) UNIQUE
#
