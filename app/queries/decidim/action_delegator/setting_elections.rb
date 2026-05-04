# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # Finds all the elections that use the given setting either as a Corporate Governance
    # Census (census_settings.setting_id) or as the option of the Delegations Verifier
    # authorization handler (census_settings.authorization_handlers.delegations_verifier.options.setting).
    class SettingElections < Decidim::Query
      def initialize(setting)
        @setting = setting
      end

      def query
        Decidim::Elections::Election.where(
          "census_settings ->> 'setting_id' = :id OR census_settings #>> '{authorization_handlers,delegations_verifier,options,setting}' = :id",
          id: @setting.id.to_s
        )
      end
    end
  end
end
