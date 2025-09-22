# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ElectionsVotesWithPonderations < Decidim::Query
      def initialize(relation, settings)
        @relation = relation
        @settings = settings

        @participants = Arel::Table.new("decidim_action_delegator_participants")
        @ponderations = Arel::Table.new("decidim_action_delegator_ponderations")
        @votes = Arel::Table.new("decidim_elections_votes")
        @user_global_id_prefix = Decidim::User.new(id: 0).to_global_id.to_s.sub(%r{/0\z}, "/")
      end

      def query
        return relation.none if settings.blank?

        relation
          .left_joins(:votes)
          .joins(participants_join)
          .joins(ponderations_join)
      end

      private

      attr_reader :relation, :settings, :participants, :ponderations, :votes, :user_global_id_prefix

      # LEFT OUTER JOIN "decidim_action_delegator_participants"
      #       ON "decidim_action_delegator_participants"."decidim_action_delegator_setting_id" IN (1, 2, 3)
      #       AND CONCAT(#{user_global_id_prefix}, "decidim_action_delegator_participants"."decidim_user_id") = "decidim_election_votes"."voter_uid"
      #     LEFT OUTER JOIN "decidim_action_delegator_ponderations"
      #       ON "decidim_action_delegator_ponderations"."id" = "decidim_action_delegator_participants"."decidim_action_delegator_ponderation_id"
      def participants_join
        Arel::Nodes::OuterJoin.new(
          participants,
          Arel::Nodes::On.new(
            participants[:decidim_action_delegator_setting_id].in(settings.pluck(:id))
            .and(
              Arel::Nodes::NamedFunction.new(
                "CONCAT",
                [
                  Arel::Nodes.build_quoted(user_global_id_prefix),
                  participants[:decidim_user_id]
                ]
              ).eq(votes[:voter_uid])
            )
          )
        )
      end

      def ponderations_join
        Arel::Nodes::OuterJoin.new(
          ponderations,
          Arel::Nodes::On.new(
            ponderations[:id].eq(participants[:decidim_action_delegator_ponderation_id])
          )
        )
      end
    end
  end
end
