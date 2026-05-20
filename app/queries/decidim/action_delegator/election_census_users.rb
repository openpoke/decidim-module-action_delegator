# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # Query to find eligible users for corporate governance census elections
    class ElectionCensusUsers < Decidim::Query
      def initialize(election)
        @election = election
        @setting_id = election.census_settings["setting_id"]
        @authorization_handlers = election.census_settings["authorization_handlers"]&.keys
      end

      def query
        return Decidim::User.none unless election.census_manifest == "action_delegator_census" && setting

        users = if effective_authorization_handlers.present?
                  authorized_users_query(effective_authorization_handlers)
                else
                  all_confirmed_users
                end

        return users unless delegations_verifier_active?

        users.where(id: participant_user_ids_query).distinct
      end

      private

      def setting
        @setting ||= Decidim::ActionDelegator::Setting.find_by(id: @setting_id)
      end

      attr_reader :election

      def participant_user_ids_query
        setting.participants.select(:decidim_user_id)
      end

      def authorized_users_query(handlers)
        Decidim::AuthorizedUsers.new(
          organization: organization,
          handlers: handlers,
          strict: true
        ).query
      end

      def delegations_verifier_active?
        @authorization_handlers&.include?("delegations_verifier")
      end

      def effective_authorization_handlers
        @effective_authorization_handlers ||= Array(@authorization_handlers) - ["delegations_verifier"]
      end

      def all_confirmed_users
        organization.users.not_deleted.not_blocked.confirmed
      end

      def organization
        @organization ||= election.organization
      end
    end
  end
end
