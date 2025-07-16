# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # TODO: Disabled due to removal of Decidim::Consultations::Vote
    class WhodunnitVote
      def initialize(vote, user)
        @user = user
        # vote intentionally ignored
      end

      def save
        true
      end

      def save!
        true
      end

      private

      attr_reader :user
    end
  end
end
