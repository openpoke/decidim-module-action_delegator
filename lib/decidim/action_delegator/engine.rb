# frozen_string_literal: true

require "savon"
require "rails"
require "decidim/core"
require "decidim/elections"
require "deface"

module Decidim
  module ActionDelegator
    # This is the engine that runs on the public interface of action_delegator.
    # Handles all the logic related to delegation except verifications
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::ActionDelegator
      include Decidim::TranslatableAttributes

      routes do
        namespace :elections do
          get ":id/sum_of_weights", to: "results#sum_of_weights", as: :results_sum_of_weights
          namespace :admin do
            get ":id/by_type_and_weight", to: "results#by_type_and_weight", as: :results_by_type_and_weight
            get ":id/sum_of_weights", to: "results#sum_of_weights", as: :results_sum_of_weights
            get ":id/totals", to: "results#totals", as: :results_totals
          end
        end

        authenticate(:user) do
          resources :user_delegations, controller: :user_delegations, only: [:index]
          root to: "user_delegations#index"
        end
      end

      initializer "decidim_action_delegator.overrides", after: "decidim.action_controller" do
        config.to_prepare do
          Decidim::Devise::SessionsController.include(Decidim::ActionDelegator::Devise::SessionsControllerOverride)
          if Decidim.module_installed?(:elections)
            Decidim::Elections::VotesController.include(Decidim::ActionDelegator::ElectionVotesControllerOverride)
            Decidim::Elections::PerQuestionVotesController.include(Decidim::ActionDelegator::ElectionPerQuestionVotesControllerOverride)
            Decidim::Elections::ElectionsController.helper(SettingsHelper)
            Decidim::Elections::Admin::ElectionsController.helper(SettingsHelper)
          end
        end
      end

      initializer "decidim_action_delegator.authorizations" do
        next unless Decidim::ActionDelegator.authorization_expiration_time.positive?

        Decidim::Verifications.register_workflow(:delegations_verifier) do |workflow|
          workflow.action_authorizer = "Decidim::ActionDelegator::Verifications::DelegationsAuthorizer"
          workflow.engine = Decidim::ActionDelegator::Verifications::DelegationsVerifier::Engine
          workflow.expires_in = Decidim::ActionDelegator.authorization_expiration_time
          workflow.time_between_renewals = 1.minute
          workflow.options do |options|
            options.attribute :setting, type: :select, raw_choices: true, choices: lambda { |context|
              Decidim::ActionDelegator::Setting.where(organization: context[:component]&.organization).map do |setting|
                [translated_attribute(setting.title), setting.id]
              end
            }
          end
        end
      end

      initializer "decidim_action_delegator.webpacker.assets_path" do |_app|
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "decidim_action_delegator.user_menu" do
        Decidim.menu :user_menu do |menu|
          menu.add_item :vote_delegations,
                        t("vote_delegations", scope: "layouts.decidim.user_profile"),
                        decidim_action_delegator.user_delegations_path,
                        position: 5.0,
                        active: :exact
        end
      end

      initializer "decidim_action_delegator.census_registry" do
        next unless Decidim.module_installed?(:elections)

        Decidim::Elections.census_registry.register(:corporate_governance_census) do |manifest|
          manifest.admin_form = "Decidim::ActionDelegator::Admin::CorporateGovernanceCensusForm"
          manifest.admin_form_partial = "decidim/elections/admin/censuses/internal_users_form"
          manifest.voter_form = "Decidim::Elections::Censuses::InternalUsersForm"
          manifest.voter_form_partial = "decidim/elections/censuses/internal_users_form"

          manifest.user_query do |election|
            Decidim::ActionDelegator::CorporateGovernanceCensusUsers.new(election).query
          end

          manifest.census_ready_validator { |election| election.census_settings["setting_id"].present? }
        end
      end

      initializer "decidim_action_delegator.icons" do
        Decidim.icons.register(name: "weight-line", icon: "weight-line", category: "system", description: "", engine: :action_delegator)
        Decidim.icons.register(name: "user-shared-line", icon: "user-shared-line", category: "system", description: "", engine: :action_delegator)
        Decidim.icons.register(name: "arrow-go-forward-line", icon: "arrow-go-forward-line", category: "system", description: "", engine: :action_delegator)
      end
    end
  end
end
