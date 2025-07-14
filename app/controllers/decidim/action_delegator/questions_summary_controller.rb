# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # This controller handles user profile actions for this module
    class QuestionsSummaryController < ActionDelegator::ApplicationController

      def show
        # render partial: "decidim/consultations/question_votes/callout", locals: { consultation: current_consultation }
      end
    end
  end
end
