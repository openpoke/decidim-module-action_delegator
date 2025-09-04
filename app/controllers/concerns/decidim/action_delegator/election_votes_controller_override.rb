# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module ElectionVotesControllerOverride
      extend ActiveSupport::Concern

      included do
        include Decidim::ActionDelegator::DelegationHelper

        prepend_before_action :load_delegations
        prepend_before_action :clear_delegations, only: :new # rubocop:disable Rails/LexicallyScopedActionFilter
      end

      # If there is a delegation, we vote as the granter, we don't use the census voter_uid default logic
      # as the granter might not be verified (this might be changed in the future, or put as an option)
      def voter_uid
        @voter_uid ||= if @delegator
                         @delegator.to_global_id.to_s
                       else
                         election.census.voter_uid(election, session_attributes, current_user:)
                       end
      end

      private

      def load_delegations
        return unless user_signed_in?

        @delegation = delegations_for(election, current_user).find_by(id: delegation_id)
        @delegator = @delegation&.user
        return unless @delegator

        session[:delegation_id] = @delegation.id
        flash.now[:warning] = t("decidim.action_delegator.elections.votes.delegated_voting", name: @delegator.name)
      end

      def delegation_id
        params[:delegation].presence || session[:delegation_id]
      end

      def clear_delegations
        session.delete(:delegation_id)
      end
    end
  end
end
