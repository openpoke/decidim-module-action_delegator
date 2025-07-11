# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Verifications
      class DelegationsAuthorizer < Decidim::Verifications::DefaultActionAuthorizer
        def authorize
          status = super
          return status unless status == [:ok, {}]

          # if used outside a consultation, allow all
          return [:ok, {}] if election.blank?
          return [:ok, {}] if belongs_to_election? && user_in_census?

          [:unauthorized, { extra_explanation: extra_explanations }]
        end

        private

        def belongs_to_election?
          return false unless setting&.election

          setting.election == election
        end

        def user_in_census?
          return false unless setting&.participants

          setting.participants.exists?(decidim_user: authorization.user) || setting.participants.exists?(census_params)
        end

        def census_params
          return @census_params if @census_params

          @census_params = { email: authorization.user.email }
          @census_params[:phone] = authorization.metadata["phone"] if setting.phone_required?
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
          @setting ||= Decidim::ActionDelegator::Setting.find_by(election:)
        end

        def election
          byebug
          @election ||= Decidim::Elections::Election.find_by(id: authorization.metadata["election_id"])
        end

        def manifest
          @manifest ||= Decidim::Verifications.find_workflow_manifest(authorization&.name)
        end
      end
    end
  end
end
