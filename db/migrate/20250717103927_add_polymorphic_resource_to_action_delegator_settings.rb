class AddPolymorphicResourceToActionDelegatorSettings < ActiveRecord::Migration[7.2]
  def change
    change_table :decidim_action_delegator_settings do |t|
      t.references :resource, polymorphic: true, index: { name: "idx_action_delegator_settings_resource" }
    end
  end
end
