# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module ElectionPerQuestionVotesControllerOverride
      extend ActiveSupport::Concern

      included do
        include Decidim::ActionDelegator::VotesControllerMethods
        helper Decidim::ActionDelegator::DelegationHelper

        alias_method :original_next_vote_step_action, :next_vote_step_action

        # rubocop:disable Rails/LexicallyScopedActionFilter
        prepend_before_action :load_delegations

        before_action :set_delegation_messages, except: [:waiting, :receipt]

        # ensure PaperTrail context is set correctly to the current_user
        # This is only for auditing purposes
        before_action :set_paper_trail_whodunnit, if: :user_signed_in?
        before_action :set_paper_trail_controller_info, if: :user_signed_in?
        # rubocop:enable Rails/LexicallyScopedActionFilter

        private

        def next_vote_step_action
          result = original_next_vote_step_action
          # if delegation active, add the param
          result[:delegation] = delegation_id if delegation_id.present?
          result
        end
      end

      private

      # buffer per-person
      def votes_buffer
        session[:votes_buffer] ||= {}
        session[:votes_buffer][voter_uid] ||= {}
        session[:votes_buffer][voter_uid]
      end

      def delegation_id
        params[:delegation]
      end

      def set_delegation_messages
        console
        return unless user_signed_in?
        return unless @delegator

        if @delegator
          flash.now[:warning] = t("decidim.action_delegator.elections.votes.delegated_voting", name: @delegator.name)
        elsif delegations.any?
          flash.now[:info] = t("decidim.action_delegator.elections.votes.self_voting", name: current_user.name)
        end
      end
    end
  end
end
