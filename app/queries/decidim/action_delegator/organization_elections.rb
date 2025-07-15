# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class OrganizationElections < Decidim::Query
      def self.for(organization)
        new(organization).query
      end

      def initialize(organization)
        @organization = organization
      end

      def query
        Decidim::Elections::Election.where(id: query_ids)
      end

      def query_ids
        participatory_space_types.flat_map do |klass|
          Decidim::Elections::Election
            .joins(:component)
            .where(decidim_components: { participatory_space_type: klass.name })
            .joins("INNER JOIN #{klass.table_name} ON #{klass.table_name}.id = decidim_components.participatory_space_id")
            .where("#{klass.table_name}.decidim_organization_id = ?", @organization.id)
            .to_a
        end.uniq
      end

      private

      def participatory_space_types
        [
          Decidim::ParticipatoryProcess,
          Decidim::Assembly
        ]
      end
    end
  end
end
