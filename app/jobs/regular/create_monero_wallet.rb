# frozen_string_literal: true

module Jobs
  # Building the watch-only wallet talks to the RPC and can take a moment, so
  # enrolling returns immediately and this finishes the job. The member sees the
  # status in their preferences.
  class CreateMoneroWallet < ::Jobs::Base
    def execute(args)
      user_id = args[:user_id]
      wallet = DiscourseMoneroTips.get_wallet(user_id)
      return if wallet.blank? || wallet["status"] == "ready"
      return unless DiscourseMoneroTips::MoneroWalletRpc.configured?

      rpc = DiscourseMoneroTips::MoneroWalletRpc.new

      DiscourseMoneroTips::MoneroWalletRpc.with_lock do
        rpc.close_wallet
        rpc.create_wallet(
          filename: wallet["wallet"],
          address: wallet["address"],
          view_key: wallet["view_key"],
          restore_height: wallet["restore_height"],
        )
        rpc.close_wallet
      end

      DiscourseMoneroTips.store_wallet(user_id, wallet.merge("status" => "ready", "error" => nil))
    rescue DiscourseMoneroTips::MoneroWalletRpc::Error => e
      DiscourseMoneroTips.set_wallet_error(user_id, e.message)
    end
  end
end
