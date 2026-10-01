# discourse-monero-tips

[![Linting and Tests](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml/badge.svg)](https://github.com/somos-criptonautas/discourse-monero-tips/actions/workflows/plugin-linting-and-tests.yml)

**ENGLISH** | [ESPAÑOL](README.es.md)

Member-to-member Monero tips. Each member publishes their own wallet address; tips go straight from one wallet to the other. The forum never holds funds, never holds keys, and — in this version — never confirms that a tip arrived.

## How it works

1. A member pastes their Monero address into **Preferences → Profile**.
2. The address is validated and stored as a public user field.
3. A tip icon appears next to their name on every post and on their profile.
4. Anyone clicking it gets the address, a QR code, and a `monero:` link that opens their own wallet.

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
| `monero_tips_icon` | The tip icon. Defaults to `ph-dt-xmr`, which comes from our Phosphor duotone icon set — change it to one your own set has (`coins` and `hand-holding-dollar` ship with Discourse) |

## What this does not do

**Nothing is verified.** Monero amounts are encrypted, so an address alone tells nobody whether a payment happened — not the forum, not the tipper, not the member being tipped. So there are deliberately no tip counts, no totals, no leaderboard and no badges here: every one of those would be a number this plugin cannot stand behind.

A wrong address cannot lose anyone's money. Monero addresses carry a checksum and the sender's wallet refuses to spend to a broken one, so a typo fails to send rather than paying a stranger. Validation here is only a format check, which is why the field is yours to double-check.

## Verified tips, later

Verification is possible without the forum ever touching funds, and it needs a Monero node — which a forum already running BTCPay with Monero enabled has. Two ways, which can coexist:

- **Per-tip proof.** The tipper pastes the transaction id and its transaction key; the forum checks it against the node (`check_tx_key`). No secret is stored, and because only the sender holds that key, the proof also establishes who sent it. Manual, but keyless.
- **View key.** A member who opts in supplies their private view key once, and tips to them are then detected automatically. A view key cannot spend, so this is still non-custodial — but it is a permanent secret that reveals every incoming payment to that wallet, and it cannot be rotated without moving wallets. Anyone handing one over has to be told that plainly, in the UI, at the moment they paste it.

Badges and points would hang off either path, since both produce a tip the forum can actually vouch for.

## Development

```bash
pnpm install && pnpm lint
```

Specs: `bundle exec rspec plugins/discourse-monero-tips/spec`. Frontend: `/qunit?filter=Monero`.

## License

GPL-3.0. See [LICENSE](LICENSE).

Text of this README under [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
