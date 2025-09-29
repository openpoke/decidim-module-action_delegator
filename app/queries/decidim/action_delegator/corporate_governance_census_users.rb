# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # Query to find eligible users for corporate governance census elections
    class CorporateGovernanceCensusUsers < Decidim::Query
      def initialize(election)
        @election = election
        @setting_id = election.census_settings["setting_id"]
        @authorization_handlers = election.census_settings["authorization_handlers"]&.keys
      end

      def query
        return Decidim::User.none unless @setting_id

        setting = Decidim::ActionDelegator::Setting.find_by(id: @setting_id)
        return Decidim::User.none unless setting

        if @authorization_handlers.present?
          authorized_participants_and_delegates(setting)
        else
          all_confirmed_users
        end
      end

      private

      attr_reader :election

      def authorized_participants_and_delegates(setting)
        participant_ids = setting.participants.pluck(:decidim_user_id)
        delegation_ids = setting.delegations.joins(:grantee).pluck("decidim_action_delegator_delegations.grantee_id")

        eligible_user_ids = (participant_ids + delegation_ids).compact.uniq
        return @election.organization.users.none if eligible_user_ids.empty?

        base_scope = @election.organization.users.where(id: eligible_user_ids)

        Decidim::AuthorizedUsers.new(
          organization: @election.organization,
          handlers: @authorization_handlers,
          strict: true
        ).query.where(id: base_scope.select(:id))
      end

      def all_confirmed_users
        @election.organization.users.not_deleted.not_blocked.confirmed
      end
    end
  end
end
