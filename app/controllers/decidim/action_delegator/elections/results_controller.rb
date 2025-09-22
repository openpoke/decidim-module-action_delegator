# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Elections
      class ResultsController < ActionDelegator::ApplicationController
        include ::Decidim::ActionDelegator::SettingsHelper

        # TODO: authentication, ensure published results
        def sum_of_weights
          render json: {
            id: election.id,
            ongoing: election.ongoing?,
            questions: election.questions.map do |question|
              {
                id: question.id,
                body: translated_attribute(question.body),
                published_results: question.published_results?,
                response_options: elections_question_weighted_responses(question).map do |option|
                  option.slice!(:id, :question_id, :body) unless election.result_published_questions.include?(question)
                  option
                end
              }
            end
          }
        end

        private

        def election
          @election ||= Decidim::Elections::Election.published.includes(questions: { votes: :versions }).find(params[:id])
        end
      end
    end
  end
end
