# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class AuthorizedResources < Decidim::Query
      # Finds all the resources that have configured the action delegator verifier
      # Note that currently only returns elections (Decidim::Election)
      # In the future components could be returned here as well
      def initialize(setting:)
        @setting = setting
      end

      def query
        condition = [
          "(census_manifest = 'internal_users' AND census_settings -> 'authorization_handlers' -> 'delegations_verifier' -> 'options' -> 'setting' ? :setting_id) OR " \
          "(census_manifest = 'action_delegator_census' AND census_settings ->> 'setting_id' = :setting_id)",
          { setting_id: @setting.id.to_s }
        ]

        Decidim::Elections::Election.where(component: components).where(condition)
      end

      def components
        Decidim::PublicComponents.for(@setting.organization, manifest_name: "elections")
      end
    end
  end
end
