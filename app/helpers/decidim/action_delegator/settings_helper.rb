# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module SettingsHelper
      include ActionView::Helpers::NumberHelper

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
        # Use size instead of count since votes are preloaded
        total_votes = question.votes.size

        ElectionsQuestionResponsesByType.new(question, current_resource_settings).query.map do |option|
          ponderation ||= Decidim::ActionDelegator::Ponderation.find_by(id: option.ponderation_id)
          votes_count = option.votes_total || 0
          votes_count_text = I18n.t("votes_count", scope: "decidim.elections.admin.dashboard.questions_table", count: votes_count)
          votes_percent = total_votes.positive? ? (option.votes_total.to_f / total_votes) * 100 : 0
          {
            id: option.id,
            body: translated_attribute(option.body),
            votes_count: votes_count,
            votes_count_text: votes_count_text,
            votes_percent: votes_percent,
            votes_percent_text: number_to_percentage(votes_percent, precision: 1),
            ponderation_id: ponderation&.id,
            ponderation_title: ponderation&.title || "-"
          }
        end
      end

      def elections_question_weighted_responses(question)
        # Use size instead of count since votes are preloaded
        total_votes = question.votes.size

        question_totals = {}
        responses = ElectionsQuestionWeightedResponses.new(question, current_resource_settings).query.map do |option|
          question_totals[question.id] ||= 0.0
          question_totals[question.id] += option.weighted_votes_total.to_f
          option
        end

        responses.map do |option|
          votes_count = option.weighted_votes_total || 0
          votes_percent = total_votes.positive? ? (option.weighted_votes_total.to_f / question_totals[question.id]) * 100 : 0
          {
            id: option.id,
            question_id: question.id,
            body: translated_attribute(option.body),
            votes_count: votes_count,
            votes_count_text: I18n.t("votes_count", scope: "decidim.elections.admin.dashboard.questions_table", count: votes_count),
            votes_percent: votes_percent,
            votes_percent_text: number_to_percentage(votes_percent, precision: 1)
          }
        end
      end

      def elections_question_stats(question)
        question_totals = {}
        ElectionsQuestionWeightedResponses.new(question, current_resource_settings).query.each do |option|
          question_totals[question.id] ||= 0.0
          question_totals[question.id] += option.weighted_votes_total.to_f
        end

        # Use preloaded votes association
        votes = question.votes
        unweighted_votes = votes.size
        weighted_votes = question_totals[question.id].to_f.round
        # Note that this works because votes cannot be edited, only created or destroyed. So only one version will exist per vote (the creation event)
        delegated_votes = votes.select { |vote| vote.versions.any? { |v| v.decidim_action_delegator_delegation_id.present? } }.size
        participants = votes.map(&:voter_uid).uniq.size

        {
          participants: participants,
          participants_text: I18n.t("participants_count", scope: "decidim.action_delegator.elections.admin.dashboard.questions_table", count: participants),
          unweighted_votes: unweighted_votes,
          unweighted_votes_text: I18n.t("votes_count", scope: "decidim.elections.admin.dashboard.questions_table", count: unweighted_votes),
          weighted_votes: weighted_votes,
          weighted_votes_text: I18n.t("votes_count", scope: "decidim.elections.admin.dashboard.questions_table", count: weighted_votes),
          delegated_votes: delegated_votes,
          delegated_votes_text: I18n.t("votes_count", scope: "decidim.elections.admin.dashboard.questions_table", count: delegated_votes)
        }
      end
    end
  end
end
