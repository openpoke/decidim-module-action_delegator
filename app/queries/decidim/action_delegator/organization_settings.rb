# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class OrganizationSettings < Decidim::Query
      def initialize(organization)
        @organization = organization
      end

      def query
        Setting
          .joins(:election)
          .merge(organization_elections)
      end

      def active
        Setting
          .joins(:election)
          .merge(organization_elections.ongoing)
      end

      private

      attr_reader :organization

      def organization_elections
        Decidim::Elections::Election
          .joins(:component)
          .joins("INNER JOIN decidim_participatory_processes ON decidim_participatory_processes.id = decidim_components.participatory_space_id")
          .where(decidim_components: { participatory_space_type: "Decidim::ParticipatoryProcess" })
          .where("decidim_participatory_processes.decidim_organization_id = ?", organization.id)
      end
    end
  end
end
