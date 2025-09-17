# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module VotesControllerMethods
      include Decidim::ActionDelegator::DelegationHelper

      # If there is a delegation, we vote as the granter, we don't use the census voter_uid default logic
      # as the granter might not be verified (this might be changed in the future, or put as an option)
      def voter_uid
        @voter_uid ||= if @delegator
                         @delegator.to_global_id.to_s
                       else
                         election.census.voter_uid(election, session_attributes, current_user:)
                       end
      end

      def delegations
        @delegations ||= delegations_for(election, current_user)
      end

      def delegation
        @delegation ||= delegations.find_by(id: delegation_id)
      end

      def load_delegations
        return unless user_signed_in?

        @delegator = delegation&.user
        return unless @delegator

        session[:delegation_id] = delegation.id
      end

      def clear_delegations
        session.delete(:delegation_id)
      end

      def info_for_paper_trail
        return super unless delegation

        super.merge(decidim_action_delegator_delegation_id: delegation.id)
      end
    end
  end
end
