# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module SettingsHelper
      def current_resource_settings
        @current_resource_settings ||= if defined?(election) && election.present?
                                         settings_for(election)
                                       elsif @election.present?
                                         settings_for(@election)
                                       else
                                         Decidim::ActionDelegator::Setting.none
                                       end
      end

      def settings_for(resource)
        case resource
        when Decidim::Elections::Election
          Decidim::ActionDelegator::ElectionSettings.new(resource).query
        else
          Decidim::ActionDelegator::Setting.none
        end
      end

      def delegations_for(resource, user)
        case resource
        when Decidim::Elections::Election
          Decidim::ActionDelegator::Delegation.where(
            setting: settings_for(resource),
            grantee: user
          )
        else
          Decidim::ActionDelegator::Delegation.none
        end
      end

      def participant_voted?(resource, user)
        case resource
        when Decidim::Elections::Election
          resource.votes.exists?(voter_uid: user.to_global_id.to_s)
        else
          false
        end
      end

      def elections_question_responses_by_type(question)
        ElectionsQuestionResponsesByType.new(question, current_resource_settings).query.map do |option|
          ponderation ||= Decidim::ActionDelegator::Ponderation.find_by(id: option.ponderation_id)
          {
            id: option.id,
            body: option.body,
            votes_total: option.votes_total,
            votes_percent: question.votes.count.positive? ? (option.votes_total.to_f / question.votes.count.to_f) * 100 : 0,
            ponderation_title: ponderation&.title || "-"
          }
        end
      end

      def elections_question_weighted_responses(question)
        question_totals = {}
        responses = ElectionsQuestionWeightedResponses.new(question, current_resource_settings).query.map do |option|
          question_totals[question.id] ||= 0.0
          question_totals[question.id] += option.weighted_votes_total.to_f
          option
        end

        responses.map do |option|
          {
            id: option.id,
            body: option.body,
            weighted_votes_total: option.weighted_votes_total.round,
            votes_percent: question.votes.count.positive? ? (option.weighted_votes_total.to_f / question_totals[question.id].to_f) * 100 : 0
          }
        end
      end

      def elections_question_stats(question)
        question_totals = {}
        ElectionsQuestionWeightedResponses.new(question, current_resource_settings).query.each do |option|
          question_totals[question.id] ||= 0.0
          question_totals[question.id] += option.weighted_votes_total.to_f
        end
        {
          participants: question.votes.select(:voter_uid).distinct.count,
          unweighted_votes: question.votes.count,
          weighted_votes: question_totals[question.id].to_f.round,
          # Note that this works because votes cannot be edited, only created or destroyed. So only one version will exist per vote (the creation event).
          delegated_votes: question.votes.joins(:versions).where.not(versions: { decidim_action_delegator_delegation_id: nil }).count

        }
      end
    end
  end
end
