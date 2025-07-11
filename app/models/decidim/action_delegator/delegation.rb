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
      validate :granter_is_same_organization_as_election

      delegate :election, to: :setting

      before_destroy { |record| throw(:abort) if record.grantee_voted? }

      def self.granted_to?(user, election)
        GranteeDelegations.for(election, user).exists?
      end

      def grantee_voted?
        return false unless election.questions.any?

        @grantee_voted ||= begin
          granter_votes = Decidim::Elections::Vote.where(author: granter, question: election.questions)
          granter_votes&.detect { |vote| vote.versions.exists?(whodunnit: grantee&.id) } ? true : false
        end
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

      def granter_is_same_organization_as_election
        return unless setting && setting.election
        return unless election.organization != granter.organization

        errors.add(:granter, :invalid)
      end
    end
  end
end
