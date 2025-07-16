# frozen_string_literal: true

class RemoveConstraintsFromConsultationInSettings < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :decidim_action_delegator_settings, column: :decidim_consultation_id
    remove_index :decidim_action_delegator_settings, name: "index_decidim_settings_on_decidim_election_id"
    remove_column :versions, :decidim_action_delegator_delegation_id
  end

  def down
    add_foreign_key :decidim_action_delegator_settings, :decidim_consultations, column: :decidim_consultation_id
    add_index :decidim_action_delegator_settings, :decidim_election_id, name: "index_decidim_settings_on_decidim_election_id"
    add_column :versions, :decidim_action_delegator_delegation_id, :integer
    add_index :versions, :decidim_action_delegator_delegation_id, name: "index_versions_on_decidim_action_delegator_delegation_id"
  end
end
