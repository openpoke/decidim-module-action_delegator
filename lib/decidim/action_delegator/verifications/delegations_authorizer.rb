# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Verifications
      class DelegationsAuthorizer < Decidim::Verifications::DefaultActionAuthorizer
        def authorize
          status = super

          if component && component.manifest_name == "elections"
            return [:ok, {}] if user_in_election_census?

            return [:unauthorized, { extra_explanation: extra_explanations }]
          end

          status
        end

        private

        def user_in_election_census?
          setting_id = options["setting"]
          return false unless setting_id

          setting = Decidim::ActionDelegator::Setting.find_by(id: setting_id)
          return false unless setting

          setting.participants.where(decidim_user: authorization.user)
                 .or(setting.participants.where(census_params(setting)))
                 .exists?
        end

        def census_params(setting)
          params = { email: authorization.user.email }
          params[:phone] = authorization.metadata["phone"] if setting.phone_required?
          params
        end

        def extra_explanations
          return @extra_explanations if @extra_explanations

          unless setting
            return [{
              key: "no_setting",
              params: { scope: "decidim.action_delegator.delegations_authorizer" }
            }]
          end

          @extra_explanations = [{
            key: "not_in_census",
            params: { scope: "decidim.action_delegator.delegations_authorizer" }
          }]

          @extra_explanations << {
            key: "email",
            params: { scope: "decidim.action_delegator.delegations_authorizer", email: authorization.user.email }
          }

          if setting.phone_required?
            @extra_explanations << {
              key: "phone",
              params: { scope: "decidim.action_delegator.delegations_authorizer", phone: authorization.metadata["phone"] || "---" }
            }
          end
          @extra_explanations
        end

        def setting
          @setting ||= Decidim::ActionDelegator::Setting.find_by(id: authorization.metadata["setting_id"])
        end
      end
    end
  end
end
