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
                  COUNT(decidim_elections_votes.id) AS votes_count")
          .group("#{Decidim::Elections::ResponseOption.table_name}.id, decidim_action_delegator_ponderation_id")
      end

      private

      attr_reader :question, :settings
    end
  end
end
