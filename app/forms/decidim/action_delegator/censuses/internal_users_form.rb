# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Censuses
      # This class does the same as Decidim::Elections::Censuses::InternalUsersForm
      # but it provides the extra explanations from the authorizer
      # hopefully this will be not needed form Decidim v0.32 onwards
      class InternalUsersForm < Decidim::Elections::Censuses::InternalUsersForm
        delegate :organization, to: :current_user

        attr_reader :authorization_status

        def authorization_handlers
          @authorization_handlers ||= election.census_settings&.fetch("authorization_handlers", {})&.slice(*organization.available_authorizations)
        end

        private

        def user_authenticated
          return errors.add(:base, I18n.t("decidim.elections.censuses.internal_users_form.invalid")) unless in_census?

          @authorization_status = Decidim::ActionAuthorizer::AuthorizationStatusCollection.new(authorization_handlers, current_user, election.component, election)

          return if @authorization_status.ok?

          errors.add(:base, I18n.t("decidim.elections.censuses.internal_users_form.invalid"))
        end
      end
    end
  end
end
