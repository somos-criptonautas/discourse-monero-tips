# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::MoneroTipsSync do
  fab!(:payee, :user)
  fab!(:tipper, :user)

  let(:rpc_url) { "http://monero-wallet-rpc.test/json_rpc" }
  let(:wallet_address) { "4#{"8" * 94}" }
  let(:subaddress) { "8#{"5" * 94}" }
  let(:one_xmr) { MoneroTip::ATOMIC_UNITS }

  before do
    SiteSetting.monero_tips_enabled = true
    SiteSetting.monero_tips_verified_enabled = true
    SiteSetting.monero_wallet_rpc_url = rpc_url
    SiteSetting.monero_tips_min_confirmations = 10

    DiscourseMoneroTips.store_wallet(
      payee.id,
      {
        "address" => wallet_address,
        "view_key" => "a" * 64,
        "wallet" => "w",
        "status" => "ready",
      },
    )
    MoneroTipAddress.create!(payee_id: payee.id, tipper_id: tipper.id, address: subaddress)
  end

  def transfers_return(transfers)
    stub_request(:post, rpc_url).to_return do |request|
      result =
        if JSON.parse(request.body)["method"] == "get_transfers"
          { "in" => transfers }
        else
          {}
        end

      {
        status: 200,
        body: { jsonrpc: "2.0", id: "0", result: result }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      }
    end
  end

  def transfer(overrides = {})
    {
      "txid" => "abc123",
      "address" => subaddress,
      "amount" => one_xmr,
      "confirmations" => 12,
      "timestamp" => Time.now.to_i,
    }.merge(overrides)
  end

  it "credits a confirmed payment to the tipper who owns that subaddress" do
    transfers_return([transfer])

    described_class.new.execute({})

    tip = MoneroTip.last
    expect(tip.payee_id).to eq(payee.id)
    expect(tip.tipper_id).to eq(tipper.id)
    expect(tip.amount).to eq(one_xmr)
    expect(tip.confirmed).to eq(true)
  end

  it "holds a payment below the confirmation threshold back" do
    transfers_return([transfer("confirmations" => 2)])

    described_class.new.execute({})

    expect(MoneroTip.last.confirmed).to eq(false)
  end

  it "confirms it on a later run instead of recording it twice" do
    transfers_return([transfer("confirmations" => 2)])
    described_class.new.execute({})

    transfers_return([transfer("confirmations" => 12)])
    described_class.new.execute({})

    expect(MoneroTip.count).to eq(1)
    expect(MoneroTip.last.confirmed).to eq(true)
  end

  it "records a payment to the wallet's own address with no tipper" do
    transfers_return([transfer("address" => wallet_address, "txid" => "def456")])

    described_class.new.execute({})

    expect(MoneroTip.last.tipper_id).to be_nil
  end

  it "ignores dust" do
    SiteSetting.monero_tips_min_amount = "0.5"
    transfers_return([transfer("amount" => one_xmr / 1000)])

    described_class.new.execute({})

    expect(MoneroTip.count).to eq(0)
  end

  it "remembers why a wallet failed instead of raising" do
    stub_request(:post, rpc_url).to_return(
      status: 200,
      body: { jsonrpc: "2.0", id: "0", error: { "message" => "no such wallet" } }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )

    expect { described_class.new.execute({}) }.not_to raise_error
    expect(DiscourseMoneroTips.get_wallet(payee.id)["error"]).to eq("no such wallet")
  end

  it "does nothing without an RPC configured" do
    SiteSetting.monero_wallet_rpc_url = ""

    expect { described_class.new.execute({}) }.not_to raise_error
    expect(MoneroTip.count).to eq(0)
  end

  it "awards gamification points to the tipper when a tip confirms" do
    skip("discourse-gamification not installed") unless defined?(
      ::DiscourseGamification::GamificationScoreEvent
    )

    SiteSetting.monero_tips_points_per_xmr = 10
    transfers_return([transfer])

    described_class.new.execute({})

    event = ::DiscourseGamification::GamificationScoreEvent.last
    expect(event.user_id).to eq(tipper.id)
    expect(event.points).to eq(10)
  end
end
