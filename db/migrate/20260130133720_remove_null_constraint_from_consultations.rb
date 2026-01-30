# frozen_string_literal: true

class RemoveNullConstraintFromConsultations < ActiveRecord::Migration[7.2]
  def change
    change_column_null :decidim_action_delegator_settings, :decidim_consultation_id, true
  end
end
