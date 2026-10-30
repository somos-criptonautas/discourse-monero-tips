# frozen_string_literal: true

module DiscourseMoneroTips
  class MoneroTipsController < ::ApplicationController
    requires_plugin DiscourseMoneroTips::PLUGIN_NAME

    requires_login only: %i[update enroll withdraw]

    def show
      user = fetch_user_from_params
      # Older cores leave the public check out of can_see_profile?.
      if !guardian.public_can_see_profiles? || !guardian.can_see_profile?(user)
        raise Discourse::NotFound
      end

      published = user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD]
      raise Discourse::NotFound if published.blank?

      address = DiscourseMoneroTips.tip_address_for(user, current_user)

      render json: {
               address: address,
               uri: payment_uri(address),
               qr: qr_data_url(address),
               # True when this address was minted for the viewer alone, which is
               # what lets the tip be credited to them.
               attributed: address != published,
             }
    end

    def update
      address = params[:address].to_s.strip

      if address.present? && !address.match?(DiscourseMoneroTips::ADDRESS_FORMAT)
        return render_json_error(I18n.t("monero_tips.invalid_address"), status: 422)
      end

      # Admins may set it on another account, e.g. system, which authors embedded topics.
      # Whoever sets it decides where that member's tips go, so moderators may not.
      user = params[:username].present? ? fetch_user_from_params : current_user
      raise Discourse::InvalidAccess if user != current_user && !current_user.admin?

      previous = user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD]
      user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD] = address.presence
      user.save_custom_fields

      if user != current_user && previous.to_s != address
        log_address_change(user, previous, address)
      end

      # The wallet was built from the old address, so it is no longer watching
      # the right place.
      withdraw_wallet(user) if address.blank? || address != wallet_address(user)

      render json: success_json.merge(address: address)
    end

    # Opting in to verified tips. The key cannot spend, but it does reveal every
    # incoming payment to this wallet — the interface says so before this point.
    def enroll
      unless DiscourseMoneroTips::MoneroWalletRpc.configured?
        return render_json_error(I18n.t("monero_tips.verification_unavailable"), status: 422)
      end

      address = current_user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD]
      if address.blank?
        return render_json_error(I18n.t("monero_tips.address_first"), status: 422)
      end

      view_key = params[:view_key].to_s.strip.downcase
      unless view_key.match?(DiscourseMoneroTips::VIEW_KEY_FORMAT)
        return render_json_error(I18n.t("monero_tips.invalid_view_key"), status: 422)
      end

      DiscourseMoneroTips.store_wallet(
        current_user.id,
        {
          "address" => address,
          "view_key" => view_key,
          "wallet" => "monero-tips-#{current_user.id}",
          "restore_height" => SiteSetting.monero_tips_restore_height,
          "status" => "pending",
          "error" => nil,
        },
      )

      Jobs.enqueue(:create_monero_wallet, user_id: current_user.id)

      render json: success_json.merge(status: "pending")
    end

    def withdraw
      withdraw_wallet

      render json: success_json
    end

    private

    def log_address_change(user, previous, address)
      StaffActionLogger.new(current_user).log_custom(
        "monero_address_change",
        username: user.username,
        previous_value: previous,
        new_value: address,
      )

      return if user.bot?

      shown = address.presence || I18n.t("monero_tips.no_address", locale: user.effective_locale)
      SystemMessage.create_from_system_user(
        user,
        :monero_address_changed,
        admin: current_user.username,
        address: shown,
      )
    end

    def wallet_address(user = current_user)
      DiscourseMoneroTips.get_wallet(user.id)&.dig("address")
    end

    # Forgetting the key stops the scanning. Past tips stay — they happened, and
    # the badges they earned are not taken back.
    def withdraw_wallet(user = current_user)
      DiscourseMoneroTips.remove_wallet(user.id)
      ::MoneroTipAddress.where(payee_id: user.id).delete_all
    end

    def payment_uri(address)
      "monero:#{address}"
    end

    # Drawn here because core already ships rqrcode, so no QR library has to be
    # pulled into the page.
    def qr_data_url(address)
      require "rqrcode" if !defined?(RQRCode)

      RQRCode::QRCode.new(payment_uri(address)).as_png(border_modules: 1, size: 240).to_data_url
    end
  end
end
