# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Verifications
      class DelegationsAuthorizer < Decidim::Verifications::DefaultActionAuthorizer
        def authorize
          if !authorization
            [:missing, { action: :authorize }]
          elsif authorization_expired?
            [:expired, { action: :authorize }]
          elsif !authorization.granted?
            [:pending, { action: :resume }]
          elsif invalid_setting?
            return [:unauthorized, { extra_explanation: extra_explanations }]
          else
            [:ok, {}]
          end
        end

        def invalid_setting?
          return true unless setting
          return true unless user_is_a_participant?

          false
        end

        private

        def user_is_a_participant?
          return false unless setting && setting.active?

          setting.participants.exists?(participant_params(setting))
        end

        def participant_params(setting)
          params = {}
          params[:email] = authorization.user.email if setting.email_required?
          params[:phone] = authorization.metadata["phone"] if setting.phone_required?
          params
        end

        def authorizations_path
          Decidim::Verifications::Engine.routes.url_helpers.authorizations_path
        end

        def extra_explanations
          return @extra_explanations if @extra_explanations

          @extra_explanations = []

          if setting
            if setting.active?
              @extra_explanations << {
                key: "not_in_census_html",
                params: {
                  scope: "decidim.action_delegator.delegations_authorizer",
                  census: translated_attribute(setting.title),
                  renew_path: authorizations_path
                }
              }
              if setting.email_required?
                @extra_explanations << {
                  key: "email",
                  params: { scope: "decidim.action_delegator.delegations_authorizer", email: authorization.user.email }
                }
              end
              if setting.phone_required?
                @extra_explanations << {
                  key: "phone",
                  params: { scope: "decidim.action_delegator.delegations_authorizer", phone: authorization.metadata["phone"] || "---" }
                }
              end
            else
              @extra_explanations << {
                key: "inactive_setting_html",
                params: {
                  scope: "decidim.action_delegator.delegations_authorizer",
                  census: translated_attribute(setting.title),
                  renew_path: authorizations_path
                }
              }
            end
          else
            @extra_explanations << {
              key: "no_setting_html",
              params: {
                scope: "decidim.action_delegator.delegations_authorizer",
                renew_path: authorizations_path
              }
            }
          end

          @extra_explanations
        end

        # Obtain the setting from the resource (in case is an election) or from the standard options (coming from the component/resource permissions hash) otherwise
        def setting_id
          @setting_id ||= if resource && resource.respond_to?(:census_settings) && resource.respond_to?(:census_manifest)
                            if resource.census_manifest == "action_delegator_census"
                              resource.census_settings["setting_id"]
                            else
                              resource.census_settings.dig("authorization_handlers", "delegations_verifier", "options", "setting_id")
                            end
                          else
                            options["setting"]
                          end
        end

        def setting
          @setting ||= Decidim::ActionDelegator::Setting.find_by(id: setting_id)
        end
      end
    end
  end
end
