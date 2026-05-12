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
            authorize_user_with_delegations_verifier(user)
            after_sign_in_path_for_original(user)
          end

          private

          def authorize_user_with_delegations_verifier(user)
            authorization = delegations_verifier_authorization(user)

            return unless ActionDelegator.authorize_on_login
            return unless user.present? && !user.blocked?

            form = Decidim::ActionDelegator::Verifications::DelegationsVerifierForm.new.with_context(
              current_user: user,
              active_settings: active_settings
            )
            return unless form.valid? && form&.setting&.verify_with_email? && !authorization.granted?

            Decidim::Verifications::PerformAuthorizationStep.call(authorization, form) do
              on(:ok) do
                authorization.grant!
                form.participant.update!(decidim_user: user)
                flash[:notice] = t("authorizations.update.success", scope: "decidim.verifications.sms")
                Rails.logger.info "User #{user.id} authorized with delegations verifier on login for setting #{form.setting.id}"
              end
              on(:invalid) do
                Rails.logger.warn "User #{user.id} failed authorization with delegations verifier on login for setting #{form.setting.id}"
              end
            end
          end

          def delegations_verifier_authorization(user)
            @delegations_verifier_authorization ||= Decidim::Authorization.find_or_initialize_by(
              user: user,
              name: "delegations_verifier"
            )
          end

          def active_settings
            @active_settings ||= Setting.where(organization: current_organization).active
          end
        end
      end
    end
  end
end
