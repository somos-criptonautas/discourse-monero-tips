# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseMoneroTips::MoneroTipsController do
  fab!(:user)
  fab!(:payee) { Fabricate(:user, username: "payee") }

  # A real mainnet address: 95 base58 characters starting with 4.
  let(:address) { "4#{"8" * 94}" }

  before { SiteSetting.monero_tips_enabled = true }

  describe "#update" do
    it "requires an account" do
      put "/monero-tips/address.json", params: { address: address }

      expect(response.status).to eq(403)
    end

    it "stores a valid address" do
      sign_in(user)

      put "/monero-tips/address.json", params: { address: address }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["monero_address"]).to eq(address)
    end

    it "rejects anything that is not an address" do
      sign_in(user)

      put "/monero-tips/address.json", params: { address: "not-an-address" }

      expect(response.status).to eq(422)
      expect(user.reload.custom_fields["monero_address"]).to be_blank
    end

    it "lets a member take their address down" do
      user.custom_fields["monero_address"] = address
      user.save_custom_fields
      sign_in(user)

      put "/monero-tips/address.json", params: { address: "" }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["monero_address"]).to be_blank
    end
  end

  describe "#show" do
    it "serves the address and a QR for it" do
      payee.custom_fields["monero_address"] = address
      payee.save_custom_fields

      get "/monero-tips/#{payee.username}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["address"]).to eq(address)
      expect(response.parsed_body["uri"]).to eq("monero:#{address}")
      expect(response.parsed_body["qr"]).to start_with("data:image/png;base64,")
    end

    it "404s for a member who set none" do
      get "/monero-tips/#{payee.username}.json"

      expect(response.status).to eq(404)
    end

    it "404s when the plugin is disabled" do
      SiteSetting.monero_tips_enabled = false
      payee.custom_fields["monero_address"] = address
      payee.save_custom_fields

      get "/monero-tips/#{payee.username}.json"

      expect(response.status).to eq(404)
    end
  end
end

RSpec.describe "verified Monero tips" do
  fab!(:user)
  fab!(:payee) { Fabricate(:user, username: "payee") }

  let(:address) { "4#{"8" * 94}" }
  let(:view_key) { "a" * 64 }
  let(:rpc_url) { "http://monero-wallet-rpc.test/json_rpc" }

  before do
    SiteSetting.monero_tips_enabled = true
    SiteSetting.monero_tips_verified_enabled = true
    SiteSetting.monero_wallet_rpc_url = rpc_url
  end

  def rpc_returns(result)
    stub_request(:post, rpc_url).to_return(
      status: 200,
      body: { jsonrpc: "2.0", id: "0", result: result }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  describe "enrolling" do
    before do
      payee.custom_fields["monero_address"] = address
      payee.save_custom_fields
      sign_in(payee)
    end

    it "stores the key out of reach of the serializers and queues the wallet" do
      expect_enqueued_with(job: :create_monero_wallet, args: { user_id: payee.id }) do
        put "/monero-tips/view-key.json", params: { view_key: view_key }
      end

      expect(response.status).to eq(200)
      stored = DiscourseMoneroTips.get_wallet(payee.id)
      expect(stored["view_key"]).to eq(view_key)
      expect(stored["status"]).to eq("pending")
      expect(payee.reload.custom_fields.keys).not_to include("monero_view_key")
    end

    it "rejects anything that is not a view key" do
      put "/monero-tips/view-key.json", params: { view_key: "nope" }

      expect(response.status).to eq(422)
      expect(DiscourseMoneroTips.get_wallet(payee.id)).to be_nil
    end

    it "refuses without a published address" do
      payee.custom_fields["monero_address"] = nil
      payee.save_custom_fields

      put "/monero-tips/view-key.json", params: { view_key: view_key }

      expect(response.status).to eq(422)
    end

    it "forgets the key on request and stops attributing" do
      DiscourseMoneroTips.store_wallet(
        payee.id,
        { "address" => address, "view_key" => view_key, "status" => "ready" },
      )
      MoneroTipAddress.create!(
        payee_id: payee.id,
        tipper_id: user.id,
        address: "8#{"9" * 94}",
      )

      delete "/monero-tips/view-key.json"

      expect(response.status).to eq(200)
      expect(DiscourseMoneroTips.get_wallet(payee.id)).to be_nil
      expect(MoneroTipAddress.where(payee_id: payee.id)).to be_empty
    end

    it "drops the wallet when the address it watched changes" do
      DiscourseMoneroTips.store_wallet(
        payee.id,
        { "address" => address, "view_key" => view_key, "status" => "ready" },
      )

      put "/monero-tips/address.json", params: { address: "8#{"7" * 94}" }

      expect(response.status).to eq(200)
      expect(DiscourseMoneroTips.get_wallet(payee.id)).to be_nil
    end
  end

  describe "the address a tipper is given" do
    before do
      payee.custom_fields["monero_address"] = address
      payee.save_custom_fields
    end

    it "is a subaddress minted for them when the payee enrolled" do
      DiscourseMoneroTips.store_wallet(
        payee.id,
        { "address" => address, "view_key" => view_key, "wallet" => "w", "status" => "ready" },
      )
      subaddress = "8#{"5" * 94}"
      rpc_returns("address" => subaddress, "address_index" => 3)
      sign_in(user)

      get "/monero-tips/#{payee.username}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["address"]).to eq(subaddress)
      expect(response.parsed_body["attributed"]).to eq(true)
      expect(
        MoneroTipAddress.find_by(payee_id: payee.id, tipper_id: user.id).address,
      ).to eq(subaddress)
    end

    it "is reused rather than minted twice" do
      DiscourseMoneroTips.store_wallet(
        payee.id,
        { "address" => address, "view_key" => view_key, "wallet" => "w", "status" => "ready" },
      )
      existing = "8#{"4" * 94}"
      MoneroTipAddress.create!(payee_id: payee.id, tipper_id: user.id, address: existing)
      sign_in(user)

      get "/monero-tips/#{payee.username}.json"

      expect(response.parsed_body["address"]).to eq(existing)
    end

    it "is the published address when the payee did not enrol" do
      sign_in(user)

      get "/monero-tips/#{payee.username}.json"

      expect(response.parsed_body["address"]).to eq(address)
      expect(response.parsed_body["attributed"]).to eq(false)
    end

    it "is the published address for a logged-out visitor" do
      get "/monero-tips/#{payee.username}.json"

      expect(response.parsed_body["address"]).to eq(address)
    end
  end
end
