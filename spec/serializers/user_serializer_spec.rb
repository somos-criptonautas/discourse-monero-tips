# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSerializer do
  fab!(:payee, :user)
  fab!(:tipper, :user)

  before { SiteSetting.monero_tips_enabled = true }

  def tip(tipper_id:, txid:)
    MoneroTip.create!(
      payee_id: payee.id,
      tipper_id: tipper_id,
      txid: txid,
      address: "8#{"5" * 94}",
      amount: MoneroTip::ATOMIC_UNITS,
      confirmations: 12,
      confirmed: true,
      received_at: Time.zone.now,
    )
  end

  def monero_tips
    JSON.parse(described_class.new(payee, scope: Guardian.new, root: false).to_json)["monero_tips"]
  end

  it "totals only tips from other members" do
    tip(tipper_id: tipper.id, txid: "a")
    tip(tipper_id: payee.id, txid: "b")
    tip(tipper_id: nil, txid: "c")

    expect(monero_tips["count"]).to eq(1)
    expect(monero_tips["total"].to_d).to eq(1)
  end

  it "shows nothing when the only payments were not tips" do
    tip(tipper_id: payee.id, txid: "b")

    expect(monero_tips).to be_nil
  end
end
