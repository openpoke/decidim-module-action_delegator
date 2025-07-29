# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Devise
      module SessionsControllerOverride
        extend ActiveSupport::Concern

        included do
          alias_method :after_sign_in_path_for_original, :after_sign_in_path_for

          # automatically authorize the user if theres a setting for it
          def after_sign_in_path_for(user)
            after_sign_in_path_for_original(user) unless authorize_user_with_delegations_verifier(user)
            super
          end

          private

          def authorize_user_with_delegations_verifier(user)
            setting = Decidim::ActionDelegator::Setting.where(organization: current_user.organization).active.first
            delegations_verifier_authorization = Decidim::Authorization.find_or_initialize_by(
              user: user,
              name: "delegations_verifier"
            )

            return unless ActionDelegator.authorize_on_login
            return unless user.present? && !user.blocked?
            return unless setting&.verify_with_email? && !delegations_verifier_authorization.granted?

            form = Decidim::ActionDelegator::Verifications::DelegationsVerifierForm.new.with_context(
              current_user: user,
              setting: setting
            )
            Decidim::Verifications::PerformAuthorizationStep.call(delegations_verifier_authorization, form) do
              on(:ok) do
                delegations_verifier_authorization.grant!
                form.participant.update!(decidim_user: user)
                flash[:notice] = t("authorizations.update.success", scope: "decidim.verifications.sms")
                return true
              end
            end
          end
        end
      end
    end
  end
end
