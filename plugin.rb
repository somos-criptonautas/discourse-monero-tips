# frozen_string_literal: true

# name: discourse-monero-tips
# about: Member-to-member Monero tips that go straight to each member's own wallet
# version: 0.1.0
# authors: Criptonautas
# url: https://github.com/somos-criptonautas/discourse-monero-tips
# required_version: 3.4.0

enabled_site_setting :monero_tips_enabled

register_asset "stylesheets/monero-tips.scss"

module ::DiscourseMoneroTips
  PLUGIN_NAME = "discourse-monero-tips"
  ADDRESS_FIELD = "monero_address"

  # Base58 without 0, O, I and l. A standard address or a subaddress is 95
  # characters (4… or 8…); an integrated address is 106 (4…). The sender's
  # wallet checks the embedded checksum before it will spend, so a typo here
  # can only fail to send — it cannot pay the wrong person.
  BASE58 = "[1-9A-HJ-NP-Za-km-z]"
  ADDRESS_FORMAT = /\A(?:[48]#{BASE58}{94}|4#{BASE58}{105})\z/
end

after_initialize do
  require_relative "app/controllers/monero_tips_controller"

  # Public, and preloaded in bulk for a page of posts by TopicView, so the tip
  # icon costs no extra request. A view key, if that is ever added, must never
  # be registered here.
  allow_public_user_custom_field DiscourseMoneroTips::ADDRESS_FIELD

  Discourse::Application.routes.append do
    put "/monero-tips/address" => "discourse_monero_tips/monero_tips#update"
    get "/monero-tips/:username" => "discourse_monero_tips/monero_tips#show",
        :constraints => {
          username: RouteFormat.username,
        },
        :defaults => {
          format: :json,
        }
  end
end
