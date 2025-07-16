# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class OrganizationSettings < Decidim::Query
      def initialize(organization)
        @organization = organization
      end

      def query
        Setting.all # TODO: needs to be changed
      end

      def active
        Setting.all # TODO: needs to be changed
      end

      private

      attr_reader :organization

      def organization_elections
        Decidim::ActionDelegator::OrganizationElections.new(organization).query
      end
    end
  end
end
