# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class Delegation < ApplicationRecord
      self.table_name = "decidim_action_delegator_delegations"

      belongs_to :granter, class_name: "Decidim::User"
      belongs_to :grantee, class_name: "Decidim::User"
      belongs_to :setting,
                 foreign_key: "decidim_action_delegator_setting_id",
                 class_name: "Decidim::ActionDelegator::Setting"

      validates :granter, uniqueness: {
        scope: [:setting],
        message: I18n.t("delegations.create.error_granter_unique", scope: "decidim.action_delegator.admin")
      }

      validate :grantee_is_not_granter
      validate :granter_and_grantee_belongs_to_same_organization
      validate :granter_is_same_organization_as_context

      delegate :resource, to: :setting

      before_destroy { |record| throw(:abort) if record.grantee_voted? }

      # TODO: Replace when new context is defined
      def self.granted_to?(_user, _context)
        false
      end

      # TODO: Replace when context provides questions and votes
      def grantee_voted?
        false
      end

      # a safe way to get the user that represents the granter in this setting
      # it might not exist if the granter is not in the census
      def user
        @user ||= setting.participants.find_by(decidim_user: granter).decidim_user
      end

      private

      def grantee_is_not_granter
        return unless granter == grantee

        errors.add(:grantee, :invalid)
      end

      def granter_and_grantee_belongs_to_same_organization
        return unless granter.organization != grantee.organization

        errors.add(:grantee, :invalid)
      end

      def granter_is_same_organization_as_context
        return unless setting && granter.organization != setting.organization

        errors.add(:granter, :invalid)
      end
    end
  end
end
