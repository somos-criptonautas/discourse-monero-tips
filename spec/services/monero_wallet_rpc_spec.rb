# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseMoneroTips::MoneroWalletRpc do
  let(:rpc_url) { "http://monero-wallet-rpc.test/json_rpc" }
  let(:nonce) { "q3ZqSBRQ0YqWc/0fp+lbWg==" }

  before do
    SiteSetting.monero_wallet_rpc_url = rpc_url
    SiteSetting.monero_wallet_rpc_username = "monero-tips"
    SiteSetting.monero_wallet_rpc_password = "s3cret"
  end

  def challenge(algorithm)
    %(Digest qop="auth",algorithm=#{algorithm},realm="monero-rpc",nonce="#{nonce}",stale=false)
  end

  def digest_fields(header)
    header.delete_prefix("Digest ").scan(/(\w+)="?([^",]*)"?/).to_h
  end

  def expected_response(fields, password, digest)
    ha1 = digest.hexdigest("#{fields["username"]}:#{fields["realm"]}:#{password}")
    ha2 = digest.hexdigest("POST:#{fields["uri"]}")
    digest.hexdigest(
      [ha1, fields["nonce"], fields["nc"], fields["cnonce"], fields["qop"], ha2].join(":"),
    )
  end

  def rpc_requires_login(algorithms)
    stub_request(:post, rpc_url).to_return do |request|
      header = request.headers["Authorization"]

      if header.nil?
        next({ status: 401, headers: { "WWW-Authenticate" => algorithms.map { challenge(_1) } } })
      end

      fields = digest_fields(header)
      digest = fields["algorithm"] == "SHA-256" ? Digest::SHA256 : Digest::MD5
      ok =
        fields["nonce"] == nonce && fields["uri"] == "/json_rpc" &&
          fields["response"] == expected_response(fields, "s3cret", digest)

      next({ status: 401, headers: { "WWW-Authenticate" => challenge("MD5") } }) unless ok

      {
        status: 200,
        body: { jsonrpc: "2.0", id: "0", result: { "address" => "8#{"5" * 94}" } }.to_json,
      }
    end
  end

  it "answers the RPC's digest challenge with the configured login" do
    rpc_requires_login(%w[SHA-256 MD5])

    expect(described_class.new.create_address("x")["address"]).to eq("8#{"5" * 94}")
    expect(
      a_request(:post, rpc_url).with { |r| r.headers["Authorization"]&.include?("SHA-256") },
    ).to have_been_made.once
  end

  it "falls back to MD5 when that is all the RPC offers" do
    rpc_requires_login(%w[MD5])

    expect(described_class.new.create_address("x")["address"]).to eq("8#{"5" * 94}")
  end

  it "fails when the password is wrong" do
    SiteSetting.monero_wallet_rpc_password = "wrong"
    rpc_requires_login(%w[MD5])

    expect { described_class.new.create_address("x") }.to raise_error(
      described_class::Error,
      /refused the login/,
    )
  end

  it "fails without a login configured" do
    SiteSetting.monero_wallet_rpc_username = ""
    rpc_requires_login(%w[MD5])

    expect { described_class.new.refresh }.to raise_error(described_class::Error)
  end
end
