# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      # A form object that extends the internal users census form with setting selection.
      class CorporateGovernanceCensusForm < Decidim::Elections::Admin::Censuses::InternalUsersForm
        attribute :setting_id, Integer

        validates :setting_id, presence: true
        validate :setting_exists_and_belongs_to_organization

        # Returns the settings that need to be persisted in the census.
        def census_settings
          parent_settings = super
          parent_settings.merge("setting_id" => setting_id)
        end

        def available_settings
          @available_settings ||= Decidim::ActionDelegator::Setting
                                  .where(organization: current_organization, active: true)
                                  .order(:title)
        end

        def settings_for_select
          available_settings.map { |setting| [setting.presenter.translated_title, setting.id] }
        end

        def setting
          @setting ||= available_settings.find_by(id: setting_id) if setting_id.present?
        end

        private

        def setting_exists_and_belongs_to_organization
          return if setting_id.blank?

          return if available_settings.exists?(id: setting_id)

          errors.add(:setting_id, :invalid)
        end
      end
    end
  end
end
