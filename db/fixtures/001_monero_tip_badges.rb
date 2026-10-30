# frozen_string_literal: true

# Defined as queries over the plugin's own table, so core's badge granter does
# the granting and an admin can rename, restyle or disable either badge in the
# normal badge UI without touching the plugin.
#
# Grant times are cut to the day: a tipper's first tip and its payee's first
# receipt are the same transaction, and badge pages list grant times publicly.
MONERO_TIP_BADGES = {
  "Monero Tipper" => {
    description: "Sent a confirmed Monero tip to another member",
    query: <<~SQL,
      SELECT tipper_id AS user_id, date_trunc('day', MIN(received_at)) AS granted_at
      FROM monero_tips
      WHERE confirmed AND tipper_id <> payee_id
      GROUP BY tipper_id
    SQL
    replaces: <<~SQL,
      SELECT tipper_id AS user_id, MIN(received_at) AS granted_at
      FROM monero_tips
      WHERE confirmed AND tipper_id IS NOT NULL
      GROUP BY tipper_id
    SQL
  },
  "Tipped in Monero" => {
    description: "Received a confirmed Monero tip from another member",
    query: <<~SQL,
      SELECT payee_id AS user_id, date_trunc('day', MIN(received_at)) AS granted_at
      FROM monero_tips
      WHERE confirmed AND tipper_id <> payee_id
      GROUP BY payee_id
    SQL
    replaces: <<~SQL,
      SELECT payee_id AS user_id, MIN(received_at) AS granted_at
      FROM monero_tips
      WHERE confirmed
      GROUP BY payee_id
    SQL
  },
}

MONERO_TIP_BADGES.each do |name, attrs|
  if (badge = Badge.find_by(name: name))
    # Bring the seed of an earlier version up to date; an admin's own query stays.
    badge.update!(query: attrs[:query]) if badge.query == attrs[:replaces]
    next
  end

  Badge.create!(
    name: name,
    description: attrs[:description],
    badge_type_id: BadgeType::Bronze,
    badge_grouping_id: BadgeGrouping::Community,
    query: attrs[:query],
    icon: "hand-holding-dollar",
    listable: true,
    target_posts: false,
    enabled: true,
    auto_revoke: false,
    system: false,
  )
end
