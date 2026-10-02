# frozen_string_literal: true

# name: discourse-monero-tips
# about: Member-to-member Monero tips that go straight to each member's own wallet
# version: 0.3.0
# authors: Criptonautas
# url: https://github.com/somos-criptonautas/discourse-monero-tips
# required_version: 3.4.0

enabled_site_setting :monero_tips_enabled

register_asset "stylesheets/monero-tips.scss"
register_svg_icon "ph-dt-xmr"

add_admin_route "monero_tips.title", "discourse-monero-tips", use_new_show_route: true

module ::DiscourseMoneroTips
  PLUGIN_NAME = "discourse-monero-tips"
  ADDRESS_FIELD = "monero_address"

  # Base58 without 0, O, I and l. A standard address or a subaddress is 95
  # characters (4… or 8…); an integrated address is 106 (4…). The sender's
  # wallet checks the embedded checksum before it will spend, so a typo here
  # can only fail to send — it cannot pay the wrong person.
  BASE58 = "[1-9A-HJ-NP-Za-km-z]"
  ADDRESS_FORMAT = /\A(?:[48]#{BASE58}{94}|4#{BASE58}{105})\z/
  VIEW_KEY_FORMAT = /\A[0-9a-f]{64}\z/
end

after_initialize do
  module ::DiscourseMoneroTips
    WALLET_PREFIX = "wallet:"

    # The view key lives here rather than in a user custom field: custom fields
    # are serialized, searched and exported in ways a secret must never be.
    def self.store_wallet(user_id, data)
      ::PluginStore.set(PLUGIN_NAME, "#{WALLET_PREFIX}#{user_id}", data)
    end

    def self.get_wallet(user_id)
      ::PluginStore.get(PLUGIN_NAME, "#{WALLET_PREFIX}#{user_id}")
    end

    def self.remove_wallet(user_id)
      ::PluginStore.remove(PLUGIN_NAME, "#{WALLET_PREFIX}#{user_id}")
    end

    def self.each_wallet
      ::PluginStoreRow
        .where(plugin_name: PLUGIN_NAME)
        .where("key LIKE ?", "#{WALLET_PREFIX}%")
        .order(:key)
        .each do |row|
          data =
            begin
              JSON.parse(row.value)
            rescue JSON::ParserError
              next
            end

          yield row.key.delete_prefix(WALLET_PREFIX).to_i, data
        end
    end

    def self.set_wallet_error(user_id, message)
      wallet = get_wallet(user_id)
      return if wallet.blank?

      store_wallet(user_id, wallet.merge("status" => "error", "error" => message))
    end

    # A plugin whose migrations have not run yet must not take the forum down
    # from inside a serializer, so the table is checked once per process.
    def self.tips_table_ready?
      @tips_table_ready = ::MoneroTip.table_exists? if @tips_table_ready.nil?
      @tips_table_ready
    end

    def self.enrolled?(user_id)
      get_wallet(user_id).present?
    end

    # The address a given tipper should pay: their own subaddress of the payee's
    # wallet when the payee enrolled, so the tip can be attributed to them, and
    # the plain published address otherwise.
    def self.tip_address_for(payee, tipper)
      published = payee.custom_fields[ADDRESS_FIELD]
      return published if tipper.blank? || !enrolled?(payee.id)

      existing = ::MoneroTipAddress.find_by(payee_id: payee.id, tipper_id: tipper.id)
      return existing.address if existing

      mint_tip_address(payee, tipper) || published
    end

    def self.mint_tip_address(payee, tipper)
      wallet = get_wallet(payee.id)
      return nil if wallet.blank? || wallet["status"] != "ready"

      rpc = MoneroWalletRpc.new

      result =
        MoneroWalletRpc.with_lock do
          rpc.close_wallet
          rpc.open_wallet(wallet["wallet"])
          rpc.create_address("tip from #{tipper.username}")
        end

      ::MoneroTipAddress.create!(
        payee_id: payee.id,
        tipper_id: tipper.id,
        address: result["address"],
        address_index: result["address_index"],
      ).address
    rescue MoneroWalletRpc::Error => e
      set_wallet_error(payee.id, e.message)
      nil
    end
  end

  require_relative "app/services/monero_wallet_rpc"
  require_relative "app/models/monero_tip"
  require_relative "app/models/monero_tip_address"
  require_relative "app/controllers/monero_tips_controller"
  require_relative "app/jobs/regular/create_monero_wallet"
  require_relative "app/jobs/scheduled/monero_tips_sync"

  # Public, and preloaded in bulk for a page of posts by TopicView, so the tip
  # icon costs no extra request. The view key is deliberately not here.
  allow_public_user_custom_field DiscourseMoneroTips::ADDRESS_FIELD

  add_to_serializer(
    :user,
    :monero_tips,
    include_condition: -> {
      SiteSetting.monero_tips_enabled && DiscourseMoneroTips.tips_table_ready? &&
        MoneroTip.exists?(payee_id: object.id, confirmed: true)
    },
  ) do
    tips = MoneroTip.confirmed.where(payee_id: object.id)

    { count: tips.count, total: tips.sum(:amount).to_d / MoneroTip::ATOMIC_UNITS }
  end

  # Only the owner is told about their own wallet, and never the key itself.
  add_to_serializer(
    :current_user,
    :monero_wallet_status,
    include_condition: -> { DiscourseMoneroTips.enrolled?(object.id) },
  ) { DiscourseMoneroTips.get_wallet(object.id)&.slice("status", "error") }

  if respond_to?(:register_discourse_workflows_node)
    register_discourse_workflows_node do
      require_relative "lib/discourse_workflows/nodes/monero_tip_confirmed/v1"
      DiscourseWorkflows::Nodes::MoneroTipConfirmed::V1
    end
  end

  on(:user_destroyed) do |user|
    DiscourseMoneroTips.remove_wallet(user.id)
    ::MoneroTipAddress.where(payee_id: user.id).or(::MoneroTipAddress.where(tipper_id: user.id)).delete_all
  end

  Discourse::Application.routes.append do
    put "/monero-tips/address" => "discourse_monero_tips/monero_tips#update"
    put "/monero-tips/view-key" => "discourse_monero_tips/monero_tips#enroll"
    delete "/monero-tips/view-key" => "discourse_monero_tips/monero_tips#withdraw"
    get "/monero-tips/:username" => "discourse_monero_tips/monero_tips#show",
        :constraints => {
          username: RouteFormat.username,
        },
        :defaults => {
          format: :json,
        }
  end
end
