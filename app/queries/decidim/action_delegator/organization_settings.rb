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
        Decidim::ActionDelegator::OrganizationElections.for(organization)
      end
    end
  end
end
