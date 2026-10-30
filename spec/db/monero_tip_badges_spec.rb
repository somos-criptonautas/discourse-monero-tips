# frozen_string_literal: true

require "rails_helper"

RSpec.describe Badge do
  fab!(:payee, :user)
  fab!(:tipper, :user)

  let(:received_at) { Time.utc(2026, 10, 1, 13, 37, 42) }

  def seed
    # A fixture is meant to run again, which require_relative would not do.
    # rubocop:disable Discourse/Plugins/UseRequireRelative
    silence_warnings { load File.expand_path("../../db/fixtures/001_monero_tip_badges.rb", __dir__) }
    # rubocop:enable Discourse/Plugins/UseRequireRelative
  end

  def tip(tipper_id:, txid:)
    MoneroTip.create!(
      payee_id: payee.id,
      tipper_id: tipper_id,
      txid: txid,
      address: "8#{"5" * 94}",
      amount: MoneroTip::ATOMIC_UNITS,
      confirmations: 12,
      confirmed: true,
      received_at: received_at,
    )
  end

  def grants(name)
    DB.query(Badge.find_by!(name: name).query).to_h { [_1.user_id, _1.granted_at] }
  end

  before { seed }

  it "grants to the day, so a tipper and payee cannot be paired by grant time" do
    tip(tipper_id: tipper.id, txid: "a")

    expect(grants("Monero Tipper")).to eq(tipper.id => received_at.beginning_of_day)
    expect(grants("Tipped in Monero")).to eq(payee.id => received_at.beginning_of_day)
  end

  it "does not count self-tips or tips without a tipper" do
    tip(tipper_id: payee.id, txid: "a")
    tip(tipper_id: nil, txid: "b")

    expect(grants("Monero Tipper")).to be_empty
    expect(grants("Tipped in Monero")).to be_empty
  end

  it "updates the query an earlier version seeded, and leaves an admin's own alone" do
    tipper_badge = Badge.find_by!(name: "Monero Tipper")
    tipper_badge.update_columns(query: MONERO_TIP_BADGES["Monero Tipper"][:replaces])
    payee_badge = Badge.find_by!(name: "Tipped in Monero")
    payee_badge.update_columns(query: "SELECT 1 AS user_id, NOW() AS granted_at")

    seed

    expect(tipper_badge.reload.query).to eq(MONERO_TIP_BADGES["Monero Tipper"][:query])
    expect(payee_badge.reload.query).to eq("SELECT 1 AS user_id, NOW() AS granted_at")
  end
end
