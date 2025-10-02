# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ElectionSettings < Decidim::Query
      # Finds all the settings for the given election that have the action delegator verifier configured
      def initialize(election)
        @election = election
      end

      def query
        setting_id = case @election.census_manifest
                     when "action_delegator_census"
                       @election.census_settings["setting_id"]
                     when "internal_users"
                       @election.census_settings.dig("authorization_handlers", "delegations_verifier", "options", "setting")
                     end

        setting_id.present? ? Decidim::ActionDelegator::Setting.where(id: setting_id) : Decidim::ActionDelegator::Setting.none
      end
    end
  end
end
