# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ElectionsQuestionWeightedResponses

      def initialize(question, settings)
        @question = question
        @settings = settings
      end

      def query
        return Decidim::Elections::ResponseOption.none if question.blank? || settings.blank?

        subquery = ElectionsQuestionResponsesByType.new(question, settings).query
        Decidim::Elections::ResponseOption.unscoped
                                          .joins("INNER JOIN (#{subquery.to_sql}) AS subquery ON subquery.id = #{Decidim::Elections::ResponseOption.table_name}.id")
                                          .select(
                                            "#{Decidim::Elections::ResponseOption.table_name}.*, SUM(subquery.votes_total * subquery.ponderation_weight) AS weighted_votes_total"
                                          )
                                          .group("#{Decidim::Elections::ResponseOption.table_name}.id")
      end

      private

      attr_reader :question, :settings
    end
  end
end
