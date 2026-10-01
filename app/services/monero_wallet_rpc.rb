# frozen_string_literal: true

module DiscourseMoneroTips
  # Talks to a monero-wallet-rpc that holds nothing but watch-only wallets: a
  # view key cannot spend, so the worst a reachable RPC can do is read who paid
  # whom. It still belongs on a private network — see the README.
  class MoneroWalletRpc
    class Error < StandardError
    end

    TIMEOUT = 20

    def self.configured?
      SiteSetting.monero_tips_verified_enabled && SiteSetting.monero_wallet_rpc_url.present?
    end

    # One wallet is open at a time, so everything that touches the RPC takes the
    # same lock — the sync job and a member asking for a tip address included.
    def self.with_lock(&block)
      DistributedMutex.synchronize("monero_tips_wallet_rpc", validity: 120, &block)
    end

    def create_wallet(filename:, address:, view_key:, restore_height:)
      call(
        "generate_from_keys",
        filename: filename,
        address: address,
        viewkey: view_key,
        password: "",
        restore_height: restore_height,
        autosave_current: true,
      )
    end

    def open_wallet(filename)
      call("open_wallet", filename: filename, password: "")
    end

    def close_wallet
      call("close_wallet")
    rescue Error
      # Nothing was open, which is the state we wanted anyway.
      nil
    end

    def refresh
      call("refresh")
    end

    # Labelled with the tipper so a human reading the wallet can tell what the
    # subaddress is for; attribution itself goes by address, not by label.
    def create_address(label)
      call("create_address", account_index: 0, label: label)
    end

    def incoming_transfers
      call("get_transfers", in: true, pending: false, out: false, pool: false)["in"] || []
    end

    private

    def call(method, params = {})
      uri = URI.parse(SiteSetting.monero_wallet_rpc_url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        jsonrpc: "2.0",
        id: "0",
        method: method,
        params: params,
      }.to_json

      response =
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT,
        ) { |http| http.request(request) }

      parsed = JSON.parse(response.body)
      raise Error, parsed["error"]["message"] if parsed["error"]

      parsed["result"] || {}
    rescue JSON::ParserError, Timeout::Error, SystemCallError, SocketError, URI::Error => e
      raise Error, e.message
    end
  end
end
