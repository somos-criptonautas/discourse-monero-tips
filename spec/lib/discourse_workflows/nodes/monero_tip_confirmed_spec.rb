# frozen_string_literal: true

require "rails_helper"

# Discourse Workflows ships with newer cores only.
return unless defined?(::DiscourseWorkflows::NodeType)

require_relative "../../../../lib/discourse_workflows/nodes/monero_tip_confirmed/v1"

RSpec.describe DiscourseWorkflows::Nodes::MoneroTipConfirmed::V1, discourse_workflows: true do
  before do
    SiteSetting.monero_tips_enabled = true
    SiteSetting.monero_tips_verified_enabled = true
  end

  fab!(:payee, :user)
  fab!(:tipper, :user)

  def tip(tipper_id: tipper.id)
    MoneroTip.create!(
      payee_id: payee.id,
      tipper_id: tipper_id,
      txid: "abc#{tipper_id}",
      address: "8#{"5" * 94}",
      amount: MoneroTip::ATOMIC_UNITS / 2,
      confirmations: 12,
      confirmed: true,
      received_at: Time.zone.now,
    )
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters.deep_stringify_keys })
  end

  it "outputs the tip with its payee and tipper" do
    output = described_class.new(tip).output

    expect(output[:tip][:amount]).to eq(0.5)
    expect(output[:tip][:attributed]).to eq(true)
    expect(output[:payee][:id]).to eq(payee.id)
    expect(output[:tipper][:id]).to eq(tipper.id)
  end

  it "can be limited to attributed tips" do
    unattributed = described_class.new(tip(tipper_id: nil))

    expect(unattributed.output[:tipper]).to be_nil
    expect(unattributed.matches?(trigger_context({}))).to eq(true)
    expect(unattributed.matches?(trigger_context(attributed_only: true))).to eq(false)
    expect(described_class.new(tip).matches?(trigger_context(attributed_only: true))).to eq(true)
  end
end
