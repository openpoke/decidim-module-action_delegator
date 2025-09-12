# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class VoteDelegation
      def initialize(response, context)
        @response = response
        @context = context
      end

      def call
        # TODO: Temporarily disabled (consultation removed)
        nil
      end

      private

      attr_reader :context, :response

      def build_vote
        context.current_question.votes.build(
          author: context.delegation.granter,
          response: response
        )
      end
    end
  end
end
