# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module ElectionVotesControllerOverride
      extend ActiveSupport::Concern

      included do
        include Decidim::ActionDelegator::VotesControllerMethods

        # rubocop:disable Rails/LexicallyScopedActionFilter
        prepend_before_action :load_delegations
        prepend_before_action :clear_delegations, only: :new

        before_action :set_delegation_messages

        # ensure PaperTrail context is set correctly to the current_user
        # This is only for auditing purposes
        before_action :set_paper_trail_whodunnit, if: :user_signed_in?
        before_action :set_paper_trail_controller_info, if: :user_signed_in?
        # rubocop:enable Rails/LexicallyScopedActionFilter
      end

      private

      def set_delegation_messages
        return unless user_signed_in?
        return unless @delegator

        flash.now[:warning] = t("decidim.action_delegator.elections.votes.delegated_voting", name: @delegator.name)
      end

      def delegation_id
        params[:delegation].presence || session[:delegation_id]
      end
    end
  end
end
