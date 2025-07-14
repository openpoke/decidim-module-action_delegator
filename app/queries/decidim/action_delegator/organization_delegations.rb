# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class OrganizationDelegations < Decidim::Query
      def initialize(organization)
        @organization = organization
      end

      def query
        Delegation
          .joins(setting: :consultation)
          .merge(organization_consultations)
          .includes(:grantee, :granter)
      end

      private

      attr_reader :organization

      def organization_consultations
        Decidim::ActionDelegator::OrganizationElections.for(organization)
      end
    end
  end
end
