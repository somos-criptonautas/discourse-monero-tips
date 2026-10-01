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
