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
            votes_count: option.votes_count,
            votes_percent: question.votes.count.positive? ? (option.votes_count.to_f / question.votes.count.to_f) * 100 : 0,
            ponderation_title: ponderation&.title || "-"
          }
        end
      end
    end
  end
end
