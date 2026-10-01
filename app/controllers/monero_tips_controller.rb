# frozen_string_literal: true

module DiscourseMoneroTips
  class MoneroTipsController < ::ApplicationController
    requires_plugin DiscourseMoneroTips::PLUGIN_NAME

    requires_login only: %i[update]

    def show
      user = fetch_user_from_params
      address = user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD]
      raise Discourse::NotFound if address.blank?

      render json: { address: address, uri: payment_uri(address), qr: qr_data_url(address) }
    end

    def update
      address = params[:address].to_s.strip

      if address.present? && !address.match?(DiscourseMoneroTips::ADDRESS_FORMAT)
        return render_json_error(I18n.t("monero_tips.invalid_address"), status: 422)
      end

      current_user.custom_fields[DiscourseMoneroTips::ADDRESS_FIELD] = address.presence
      current_user.save_custom_fields

      render json: success_json.merge(address: address)
    end

    private

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
