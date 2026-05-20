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

        if @authorization_handlers.present?
          authorized_users(setting)
        else
          all_confirmed_users
        end
      end

      private

      def setting
        @setting ||= Decidim::ActionDelegator::Setting.find_by(id: @setting_id)
      end

      attr_reader :election

      def authorized_users(setting)
        authorized_granters = setting.delegations.select(:granter_id).where(grantee_id: authorized_users_query.select(:id))

        authorized_users_query.or(all_confirmed_users.where(id: authorized_granters)).distinct
      end

      def authorized_users_query
        Decidim::AuthorizedUsers.new(
          organization: organization,
          handlers: @authorization_handlers,
          strict: true
        ).query
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
