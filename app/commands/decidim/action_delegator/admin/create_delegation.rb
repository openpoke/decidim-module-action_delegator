# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class CreateDelegation < Decidim::Command
        # Public: Initializes the command.
        #
        # form         - A form object with the params.
        # delegated_by - The user performing the operation
        def initialize(form, performed_by, current_setting)
          @form = form
          @performed_by = performed_by
          @current_setting = current_setting
        end

        # Executes the command. Broadcasts these events:
        #
        # - :ok when everything is valid.
        # - :invalid if the form wasn't valid and we couldn't proceed.
        #
        # Returns nothing.
        def call
          return broadcast(:error, generic_error_message) if form.invalid? || current_setting.nil?
          return broadcast(:error, above_max_grants_error_message) if above_max_grants?

          create_delegation

          return broadcast(:ok) if delegation.persisted?

          broadcast(:error, delegation.errors.full_messages.first)
        end

        private

        attr_reader :form, :performed_by, :current_setting, :delegation

        def above_max_grants?
          grants_count >= current_setting.max_grants
        end

        def above_max_grants_error_message
          I18n.t("delegations.create.error_max_grants", scope: "decidim.action_delegator.admin")
        end

        def generic_error_message
          I18n.t("delegations.create.error", scope: "decidim.action_delegator.admin")
        end

        def grants_count
          Delegation.where(setting: current_setting, grantee_id: form.grantee_id).count
        end

        def create_delegation
          @delegation = Delegation.create(
            granter: form.granter,
            grantee: form.grantee,
            setting: current_setting
          )
        end
      end
    end
  end
end
