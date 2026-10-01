# frozen_string_literal: true

class CreateMoneroTips < ActiveRecord::Migration[7.2]
  def change
    create_table :monero_tips do |t|
      t.integer :payee_id, null: false
      t.integer :tipper_id
      t.string :txid, null: false
      t.string :address, null: false
      # Atomic units (1 XMR = 1e12), kept as given by the wallet so nothing is
      # lost to floating point.
      t.bigint :amount, null: false
      t.integer :confirmations, null: false, default: 0
      t.boolean :confirmed, null: false, default: false
      t.datetime :received_at, null: false
      t.timestamps
    end

    add_index :monero_tips, %i[payee_id txid address], unique: true
    add_index :monero_tips, :tipper_id

    create_table :monero_tip_addresses do |t|
      t.integer :payee_id, null: false
      t.integer :tipper_id, null: false
      t.string :address, null: false
      t.integer :address_index
      t.timestamps
    end

    add_index :monero_tip_addresses, %i[payee_id tipper_id], unique: true
    add_index :monero_tip_addresses, :address, unique: true
  end
end
