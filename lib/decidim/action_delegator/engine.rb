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

      routes do
        # Add engine routes here
        authenticate(:user) do
          resources :user_delegations, controller: :user_delegations, only: [:index]
          root to: "user_delegations#index"
        end
        resources :questions_summary, param: :slug, only: [:show]
      end

      initializer "decidim_action_delegator.overrides", after: "decidim.action_controller" do
        config.to_prepare do
          Decidim::Devise::SessionsController.include(Decidim::ActionDelegator::Devise::SessionsControllerOverride)
        end
      end

      initializer "decidim_action_delegator.authorizations" do
        next unless Decidim::ActionDelegator.authorization_expiration_time.positive?

        Decidim::Verifications.register_workflow(:delegations_verifier) do |workflow|
          workflow.action_authorizer = "Decidim::ActionDelegator::Verifications::DelegationsAuthorizer"
          workflow.engine = Decidim::ActionDelegator::Verifications::DelegationsVerifier::Engine
          workflow.expires_in = Decidim::ActionDelegator.authorization_expiration_time
          workflow.time_between_renewals = 1.minute
        end
      end

      initializer "decidim_action_delegator.webpacker.assets_path" do |_app|
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "decidim.user_menu" do
        Decidim.menu :user_menu do |menu|
          menu.add_item :vote_delegations,
                        t("vote_delegations", scope: "layouts.decidim.user_profile"),
                        decidim_action_delegator.user_delegations_path,
                        position: 5.0,
                        active: :exact
        end
      end

      Decidim.icons.register(name: "layout-grid-line", icon: "layout-grid-line", category: "system", description: "", engine: :core)
      Decidim.icons.register(name: "loop-right-line", icon: "loop-right-line", category: "system", description: "", engine: :core)
      Decidim.icons.register(name: "arrow-go-forward-line", icon: "arrow-go-forward-line", category: "system", description: "", engine: :core)
    end
  end
end
