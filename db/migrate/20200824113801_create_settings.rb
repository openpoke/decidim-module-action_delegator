# frozen_string_literal: true

class CreateSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :decidim_action_delegator_settings do |t|
      t.datetime :expires_at, null: false
      t.integer :max_grants, null: false, default: 0, limit: 2 # Maps to PostgreSQL smallint
      t.references :decidim_consultation, null: false, foreign_key: { to_table: :decidim_elections_elections }, index: { name: "index_decidim_settings_on_decidim_election_id" }

      t.timestamps
    end
  end
end
