# frozen_string_literal: true

module Jobs
  # Walks every enrolled wallet, asks it what came in, and records what is new.
  # Nothing here can spend: these are watch-only wallets built from a view key.
  class MoneroTipsSync < ::Jobs::Scheduled
    every 10.minutes

    def execute(_args)
      return unless DiscourseMoneroTips::MoneroWalletRpc.configured?

      rpc = DiscourseMoneroTips::MoneroWalletRpc.new

      DiscourseMoneroTips.each_wallet do |user_id, wallet|
        next if wallet["status"] != "ready"

        DiscourseMoneroTips::MoneroWalletRpc.with_lock do
          rpc.close_wallet
          rpc.open_wallet(wallet["wallet"])
          rpc.refresh
          record(user_id, rpc.incoming_transfers)
          rpc.close_wallet
        end
      rescue DiscourseMoneroTips::MoneroWalletRpc::Error => e
        DiscourseMoneroTips.set_wallet_error(user_id, e.message)
      end
    end

    private

    def record(payee_id, transfers)
      minimum = (SiteSetting.monero_tips_min_amount.to_f * MoneroTip::ATOMIC_UNITS).round
      required = SiteSetting.monero_tips_min_confirmations

      transfers.each do |transfer|
        amount = transfer["amount"].to_i
        next if amount < minimum

        # The wallet's own address receives from anywhere, so only payments to a
        # subaddress minted for one tipper can be attributed to them.
        mapping = MoneroTipAddress.find_by(payee_id: payee_id, address: transfer["address"])
        confirmations = transfer["confirmations"].to_i

        tip =
          MoneroTip.find_or_initialize_by(
            payee_id: payee_id,
            txid: transfer["txid"],
            address: transfer["address"],
          )
        was_confirmed = tip.confirmed

        tip.tipper_id = mapping&.tipper_id
        tip.amount = amount
        tip.confirmations = confirmations
        tip.confirmed = confirmations >= required
        tip.received_at ||= Time.at(transfer["timestamp"].to_i).utc
        tip.save!

        next if !tip.confirmed || was_confirmed

        award_points(tip)
        DiscourseEvent.trigger(:monero_tip_confirmed, tip)
      end
    end

    # Badges are left to core: they are defined as queries over this table, so
    # the badge granter grants them without any help from here.
    def award_points(tip)
      per_xmr = SiteSetting.monero_tips_points_per_xmr
      return if per_xmr <= 0 || tip.tipper_id.blank?
      return unless defined?(::DiscourseGamification::GamificationScoreEvent)

      points = (tip.amount_xmr * per_xmr).round
      return if points <= 0

      ::DiscourseGamification::GamificationScoreEvent.create!(
        user_id: tip.tipper_id,
        date: tip.received_at.to_date,
        points: points,
        description: "Monero tip #{tip.txid}",
      )
    rescue StandardError => e
      Rails.logger.warn("[monero-tips] could not award points: #{e.message}")
    end
  end
end
