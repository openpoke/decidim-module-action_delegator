# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ElectionSettings < Decidim::Query
      # Finds all the settings for the given election that have the action delegator verifier configured
      def initialize(election)
        @election = election
      end

      def query
        setting_ids = @election.census_settings.dig("authorization_handlers", "delegations_verifier", "options", "setting")
        return Decidim::ActionDelegator::Setting.none unless setting_ids.present?

        Decidim::ActionDelegator::Setting.where(id: setting_ids)
      end
    end
  end
end
