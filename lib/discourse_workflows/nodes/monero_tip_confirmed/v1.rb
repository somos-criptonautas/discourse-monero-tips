# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module MoneroTipConfirmed
        # Fires once per tip, when the sync job first sees it pass the
        # confirmation threshold. A tip to a member's own address cannot be
        # attributed, so the tipper is null for those.
        class V1 < DiscourseWorkflows::NodeType
          OUTPUT_SCHEMA =
            DiscourseWorkflows::Schema.document(
              "tip" => {
                "type" => "object",
                "properties" => {
                  "id" => {
                    "type" => "integer",
                  },
                  "txid" => {
                    "type" => "string",
                  },
                  "address" => {
                    "type" => "string",
                  },
                  "amount" => {
                    "type" => "number",
                    "description" => "In XMR",
                  },
                  "confirmations" => {
                    "type" => "integer",
                  },
                  "received_at" => {
                    "type" => "string",
                  },
                  "attributed" => {
                    "type" => "boolean",
                  },
                },
              },
              "payee" => {
                "type" => "object",
                "properties" => DiscourseWorkflows::Schema::USER_PROPERTIES,
              },
              "tipper" => {
                "type" => %w[object null],
                "properties" => DiscourseWorkflows::Schema::USER_PROPERTIES,
              },
            ).freeze

          description(
            name: "trigger:monero_tip_confirmed",
            version: "1.0",
            defaults: {
              icon: "ph-dt-xmr",
              color: "orange",
            },
            group: "discourse_triggers",
            event: :monero_tip_confirmed,
            available: -> do
              SiteSetting.monero_tips_enabled && SiteSetting.monero_tips_verified_enabled
            end,
            unavailable_reason_key:
              "discourse_workflows.node_unavailable.requires_monero_verified_tips",
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              attributed_only: {
                type: :boolean,
                required: false,
                default: false,
                ui: {
                  control: :boolean,
                },
              },
            },
          )

          def initialize(tip)
            super(parameters: {})
            @tip = tip
          end

          def valid?
            @tip.present? && @tip.confirmed && payee.present?
          end

          def output
            {
              tip: {
                id: @tip.id,
                txid: @tip.txid,
                address: @tip.address,
                amount: @tip.amount_xmr.to_f,
                confirmations: @tip.confirmations,
                received_at: @tip.received_at&.iso8601,
                attributed: tipper.present?,
              },
              payee: serialize_user(payee),
              tipper: tipper && serialize_user(tipper),
            }
          end

          def matches?(trigger_ctx)
            attributed_only = trigger_ctx.get_node_parameter("attributed_only", false)
            !ActiveModel::Type::Boolean.new.cast(attributed_only) || tipper.present?
          end

          private

          def payee
            @tip.payee
          end

          def tipper
            @tip.tipper
          end
        end
      end
    end
  end
end
