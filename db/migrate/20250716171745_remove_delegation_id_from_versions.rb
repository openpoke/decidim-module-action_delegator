class RemoveDelegationIdFromVersions < ActiveRecord::Migration[7.2]
  def change
    remove_column :versions, :decidim_action_delegator_delegation_id
  end
end
