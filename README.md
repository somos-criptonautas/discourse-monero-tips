# discourse-monero-tips

[![Linting and Tests](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml/badge.svg)](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml)

**ENGLISH** | [ESPAÑOL](README.es.md)

Maintained by Criptonautas. Not affiliated with or endorsed by Discourse (Civilized Discourse Construction Kit, Inc.).

**Monero Tips**: member-to-member tips in Monero. Each member publishes their own wallet address; tips go straight from one wallet to the other. The forum never holds funds, never holds keys, and — in this version — never confirms that a tip arrived.

## How it works

1. A member pastes their Monero address into **Preferences → Profile**.
2. The address is validated and stored as a public user field.
3. A tip icon appears at the bottom-left of each of their posts and on their profile.
4. Anyone clicking it gets the address, a QR code, and a `monero:` link that opens their own wallet.

Admins can set the address on another account from that user's preferences, e.g. `system`, which authors embedded topics. Each change lands in the staff action log as `monero_address_change`, and the member gets a message about it. Moderators cannot.

That is the whole flow. There is no payment, callback or webhook, because nothing passes through Discourse.

## Installation

Add to `containers/app.yml` and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/somos-criptonautas/discourse-monero-tips.git
```

Then enable `monero_tips_enabled`.

## Settings

| Setting | Purpose |
|---|---|
| `monero_tips_enabled` | Off by default |
| `monero_tips_icon` | The tip icon, picked from a dropdown. Defaults to `ph-dt-xmr`, a Monero glyph the plugin bundles, so it shows for every visitor without any icon set of your own |
| `monero_tips_verified_enabled` | Lets members opt in to verified tips. Needs a wallet RPC — see below |
| `monero_wallet_rpc_url` | The wallet RPC endpoint |
| `monero_tips_restore_height` | Where new watch-only wallets start scanning |
| `monero_tips_min_confirmations` | Confirmations before a tip counts. Default 10 |
| `monero_tips_min_amount` | Dust threshold in XMR |
| `monero_tips_points_per_xmr` | Gamification points for the tipper. 0 is off |

## What this does not do, until you turn on verified tips

**Nothing is verified.** Monero amounts are encrypted, so an address alone tells nobody whether a payment happened — not the forum, not the tipper, not the member being tipped. So there are deliberately no tip counts, no totals, no leaderboard and no badges here: every one of those would be a number this plugin cannot stand behind.

A wrong address cannot lose anyone's money. Monero addresses carry a checksum and the sender's wallet refuses to spend to a broken one, so a typo fails to send rather than paying a stranger. Validation here is only a format check, which is why the field is yours to double-check.

## Verified Monero Tips

Off until a Monero wallet RPC is reachable, and opt-in per member even then. Nothing about it is custodial: the forum only ever holds **view** keys, which cannot spend.

### What the forum needs

A `monero-wallet-rpc` that holds nothing but watch-only wallets, pointed at a node — the one a BTCPay Server with Monero enabled already runs:

```yaml
monero-tips-wallet-rpc:
  image: sethsimmons/simple-monero-wallet-rpc:latest
  command: >
    --wallet-dir /wallet
    --daemon-address monerod:18081
    --trusted-daemon
    --rpc-bind-port 18083
    --rpc-bind-ip 0.0.0.0
    --confirm-external-bind
    --rpc-login monero-tips:CHANGE-ME
  volumes:
    - monero-tips-wallets:/wallet
```

**It must not be reachable from outside your network.** The RPC keeps one wallet open for every client, so anything that reaches it without the login could switch wallets while the forum mints a tip address and send tips somewhere else. Keep it on the internal network with Discourse and the node, never published to the host. The login is HTTP digest, which hides the password but not the traffic, view keys included; if the RPC is anywhere but a network only Discourse reaches, serve it over HTTPS with a certificate Discourse trusts and use an `https://` URL.

Then set `monero_wallet_rpc_url` to `http://monero-tips-wallet-rpc:18083/json_rpc`, `monero_wallet_rpc_username` and `monero_wallet_rpc_password` to the two halves of `--rpc-login`, set `monero_tips_restore_height` near the current block height so new wallets do not rescan the whole chain, and turn on `monero_tips_verified_enabled`.

### What a member does

They paste their **private view key** in Preferences → Profile, after reading what that means. The plugin builds a watch-only wallet from their address plus that key, and from then on every member who opens their tip modal gets a subaddress minted for that pair. That is what makes a tip attributable: Monero transfers carry no sender, but they do say which subaddress received them. Only payments to those subaddresses are recorded; whatever else reaches the wallet is not. Nobody is given a subaddress in their own wallet.

A member can turn it off at any time; the key is forgotten and scanning stops. Tips already recorded stay, and badges already earned are not revoked.

### What it costs them

A view key reveals **every** incoming payment to that wallet, forever, to whoever holds it, and it cannot be rotated without moving to a new wallet. It can never spend. The interface says this above the field, before the key can be pasted — if you translate or restyle this plugin, keep it that way.

### Badges and points

Two badges ship as seeds, defined as SQL queries over the plugin's own table, so core's badge granter does the granting and you can rename, restyle or disable either one in the normal badge UI:

| Badge | Granted to |
|---|---|
| Monero Tipper | anyone whose confirmed tip reached another member |
| Tipped in Monero | anyone who received a confirmed tip from another member |

Grant times are cut to the day, so a badge page does not pair a tipper with their payee by the second.

`monero_tips_points_per_xmr` additionally gives the tipper gamification points per XMR, if `discourse-gamification` is installed. A tip counts as confirmed at `monero_tips_min_confirmations` (10 by default), and anything under `monero_tips_min_amount` is ignored as dust.

### Workflows

With Discourse Workflows enabled, a **Monero tip confirmed** trigger fires once per tip, when it reaches `monero_tips_min_confirmations`. It carries the tip (`txid`, `amount` in XMR, `confirmations`, `received_at`, `attributed`), the `payee` and the `tipper` — null once that account is gone. Its **Attributed tips only** option skips those. Plugins can also listen for the `:monero_tip_confirmed` event directly.

### What is still unverifiable

A tip paid to a member's published address rather than to a minted subaddress is not recorded — the forum cannot tell it from any other payment. Tips to members who never opted in are not seen at all, and the modal says so.

Attribution is only as honest as the payee. The payee's wallet can pay any subaddress in it, so a payee can credit a tip to a member who never paid, and a member could enroll the address and view key of a wallet that is not theirs. Treat the badges, totals and `monero_tips_points_per_xmr` as claims by the payee, not proof.

## Development

```bash
pnpm install && pnpm lint
```

Specs: `bundle exec rspec plugins/discourse-monero-tips/spec`. Frontend: `/qunit?filter=Monero`.

## License

MIT. See [LICENSE](LICENSE).

Text of this README under [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
