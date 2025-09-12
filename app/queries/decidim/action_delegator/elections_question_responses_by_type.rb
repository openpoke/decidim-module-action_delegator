# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ElectionsQuestionResponsesByType
      # Add your query logic here

      def initialize(question, settings)
        @question = question
        @settings = settings
      end

      def query
        return Decidim::Elections::ResponseOption.none if question.blank? || settings.blank?

        ElectionsVotesWithPonderations
          .new(question.response_options, settings)
          .query
          .select("#{Decidim::Elections::ResponseOption.table_name}.*,
            decidim_action_delegator_ponderation_id AS ponderation_id,
            COALESCE(CAST(decidim_action_delegator_ponderations.weight AS FLOAT), 1.0) AS ponderation_weight,
            COUNT(decidim_elections_votes.id) AS votes_total")
          .group("#{Decidim::Elections::ResponseOption.table_name}.id, decidim_action_delegator_ponderation_id, decidim_action_delegator_ponderations.weight")
      end

      private

      attr_reader :question, :settings
    end
  end
end
