# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Elections
      module Admin
        class ResultsController < ActionDelegator::Admin::ApplicationController
          include ::Decidim::ActionDelegator::SettingsHelper

          # TODO: authentication
          def by_type_and_weight
            render json: {
              id: election.id,
              ongoing: election.ongoing?,
              questions: election.questions.map do |question|
                {
                  id: question.id,
                  response_options: elections_question_responses_by_type(question)
                }
              end
            }
          end

          def sum_of_weights
            render json: {
              id: election.id,
              ongoing: election.ongoing?,
              questions: election.questions.map do |question|
                {
                  id: question.id,
                  response_options: elections_question_weighted_responses(question)
                }
              end
            }
          end

          def totals
            render json: {
              id: election.id,
              ongoing: election.ongoing?,
              questions: election.questions.map do |question|
                { id: question.id }.merge(
                  elections_question_stats(question)
                )
              end
            }
          end

          private

          def election
            @election ||= Decidim::Elections::Election.find(params[:id])
          end
        end
      end
    end
  end
end
