# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class Permissions < Decidim::DefaultPermissions
      def permissions
        return permission_action unless user

        return Decidim::ActionDelegator::Admin::Permissions.new(user, permission_action, context).permissions if permission_action.scope == :admin

        allowed_delegation_action?

        permission_action
      end

      private
      
      def allowed_delegation_action?
        return unless delegation
        # Check that the required question verifications are fulfilled
        return unless authorized?(:vote, delegation.grantee)
      
        case permission_action.action
        when :vote_delegation
          toggle_allow(question.can_be_voted_by?(delegation.granter) && delegation.grantee == user)
        when :unvote_delegation
          toggle_allow(question.can_be_unvoted_by?(delegation.granter) && delegation.grantee == user)
        end
      end

      def authorized?(permission_action, user, resource: nil)
        return unless resource || question
      
        ActionAuthorizer.new(user, permission_action, question, resource).authorize.ok?
      end

      def question
        @question ||= context.fetch(:question, nil)
      end

      def delegation
        @delegation ||= context.fetch(:delegation, nil)
      end

      def ponderation
        @ponderation ||= context.fetch(:ponderation, nil)
      end

      def resource
        @resource ||= context.fetch(:resource, nil)
      end
    end
  end
end
