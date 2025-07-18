# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class FixResourcePermissions < Decidim::Command
        def initialize(resources)
          @resources = resources
          @errors = []
        end

        # Executes the command. Broadcasts these events:
        #
        # - :ok when everything is valid.
        # - :invalid if the form wasn't valid and we couldn't proceed.
        #
        # Returns nothing.
        def call
          broadcast(:ok)

          return broadcast(:invalid) if resources.blank?

          update_permissions

          return broadcast(:invalid) if errors.any?

          broadcast(:ok)
        end

        private

        attr_reader :resources, :errors

        def update_permissions
          # TODO: This won't work because `Decidim::Elections::Question` does not include `HasResourcePermission`.
          resources.each do |resource|
            resource.resource_manifest.actions.each do |action|
              resource_permission ||= resource.resource_permission || resource.build_resource_permission
              next unless resource_permission.permissions.dig(action, "authorization_handlers", "delegations_verifier").nil?

              resource_permission.permissions.deep_merge!({ action => { "authorization_handlers" => { "delegations_verifier" => {} } } })
              @errors << resource unless resource_permission.save
            end
          end
        end
      end
    end
  end
end
