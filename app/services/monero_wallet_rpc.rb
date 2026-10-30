# frozen_string_literal: true

module DiscourseMoneroTips
  # Talks to a monero-wallet-rpc that holds nothing but watch-only wallets. A
  # view key cannot spend, but whoever reaches the RPC can switch the open wallet
  # under the forum, so it takes a login and belongs on a private network — see
  # the README.
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

    def primary_address
      call("get_address", account_index: 0, address_index: [0])["address"]
    end

    def incoming_transfers
      call("get_transfers", in: true, pending: false, out: false, pool: false)["in"] || []
    end

    private

    def call(method, params = {})
      uri = URI.parse(SiteSetting.monero_wallet_rpc_url)
      body = { jsonrpc: "2.0", id: "0", method: method, params: params }.to_json

      response =
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT,
        ) do |http|
          sent = http.request(post(uri, body))
          if sent.code == "401" && SiteSetting.monero_wallet_rpc_username.present?
            sent = http.request(post(uri, body, digest_authorization(uri, sent)))
          end
          sent
        end

      raise Error, "the wallet RPC refused the login" if response.code == "401"

      parsed = JSON.parse(response.body)
      raise Error, parsed["error"]["message"] if parsed["error"]

      parsed["result"] || {}
    rescue JSON::ParserError, Timeout::Error, SystemCallError, SocketError, URI::Error => e
      raise Error, e.message
    end

    def post(uri, body, authorization = nil)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = authorization if authorization
      request.body = body
      request
    end

    DIGESTS = { "SHA-256" => Digest::SHA256, "MD5" => Digest::MD5 }

    # monero-wallet-rpc's --rpc-login only speaks HTTP digest (RFC 7616), and it
    # starts a fresh nonce on every challenge, so each call answers its own.
    def digest_authorization(uri, challenge)
      fields =
        challenge
          .get_fields("www-authenticate")
          .to_a
          .flat_map { |header| header.split(/,\s*(?=Digest )/) }
          .filter_map do |header|
            next unless header.start_with?("Digest ")
            header.scan(/(\w+)="?([^",]*)"?/).to_h
          end
      server = fields.find { |f| DIGESTS.key?(f.fetch("algorithm", "MD5")) }
      raise Error, "the wallet RPC offered no usable login" if server.nil?

      algorithm = server.fetch("algorithm", "MD5")
      hash = ->(*parts) { DIGESTS[algorithm].hexdigest(parts.join(":")) }
      username = SiteSetting.monero_wallet_rpc_username
      cnonce = SecureRandom.hex(16)
      ha1 = hash.(username, server["realm"], SiteSetting.monero_wallet_rpc_password)
      ha2 = hash.("POST", uri.request_uri)
      response = hash.(ha1, server["nonce"], "00000001", cnonce, "auth", ha2)

      %(Digest username="#{username}", realm="#{server["realm"]}", ) +
        %(nonce="#{server["nonce"]}", uri="#{uri.request_uri}", algorithm=#{algorithm}, ) +
        %(qop=auth, nc=00000001, cnonce="#{cnonce}", response="#{response}")
    end
  end
end
