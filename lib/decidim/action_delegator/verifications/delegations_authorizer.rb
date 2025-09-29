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
          # Найти setting для текущих выборов из опций
          election_setting_id = options["setting"]
          return false unless election_setting_id

          election_setting = Decidim::ActionDelegator::Setting.find_by(id: election_setting_id)
          return false unless election_setting&.participants

          # Проверить, есть ли пользователь в участниках этого setting
          election_setting.participants.exists?(decidim_user: authorization.user) ||
            election_setting.participants.exists?(census_params_for_setting(election_setting))
        end

        def census_params_for_setting(election_setting)
          params = { email: authorization.user.email }
          params[:phone] = authorization.metadata["phone"] if election_setting.phone_required?
          params
        end

        def census_params
          return @census_params if @census_params

          election_setting_id = options["setting"]
          election_setting = Decidim::ActionDelegator::Setting.find_by(id: election_setting_id)

          @census_params = { email: authorization.user.email }
          @census_params[:phone] = authorization.metadata["phone"] if election_setting&.phone_required?
          @census_params
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
          # Теперь setting берется из опций выборов, а не из метаданных авторизации
          @setting ||= Decidim::ActionDelegator::Setting.find_by(id: options["setting"])
        end
      end
    end
  end
end
