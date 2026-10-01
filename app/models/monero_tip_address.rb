# frozen_string_literal: true

# One subaddress per (payee, tipper) pair. That is what makes a tip
# attributable: Monero transfers carry no sender, but they do say which
# subaddress received them.
class MoneroTipAddress < ActiveRecord::Base
  belongs_to :payee, class_name: "User"
  belongs_to :tipper, class_name: "User"
end
