# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # This is the engine that runs on the public interface of `ActionDelegator`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::ActionDelegator::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        resources :settings do
          resources :delegations, only: [:index, :new, :create, :destroy]
          resources :ponderations
          resources :participants
          resources :invite_participants do
            post :invite_user, on: :member
            post :invite_all_users, on: :collection
            post :resend_invitation, on: :member
          end
          resources :manage_participants, only: [:new, :create, :destroy_all] do
            delete :destroy_all, on: :collection
          end
          resources :manage_delegations, only: [:new, :create]
          resources :permissions, only: [:create] do
            post :sync, on: :collection
          end
        end

        # TODO: replace with real implementation once results pages for elections are ready
        resources :elections, param: :slug, only: [] do
          get :results, on: :member
          # get :weighted_results, on: :member
          # resources :exports, only: :create, module: :elections

          # namespace :exports do
          #   resources :sum_of_weights, only: :create
          # end
        end

        root to: "delegations#index"
      end

      # marks the main "Users" menu in the admin always active when we are in the action_delegator admin space
      initializer "decidim_admin_action_delegator.main_menu" do
        Decidim.menu :admin_menu do |menu|
          if (item = menu.items.find { |it| it.identifier == :impersonatable_users })
            item.active.first << "decidim/action_delegator/admin/settings"
            item.active.first << "decidim/action_delegator/admin/ponderations"
            item.active.first << "decidim/action_delegator/admin/participants"
            item.active.first << "decidim/action_delegator/admin/manage_participants"
            item.active.first << "decidim/action_delegator/admin/delegations"
            item.active.first << "decidim/action_delegator/admin/manage_delegations"
          end
        end
      end

      initializer "decidim_admin_action_delegator.admin_user_menu" do
        Decidim.menu :admin_user_menu do |menu|
          menu.add_item :action_delegator,
                        I18n.t("menu.delegations", scope: "decidim.action_delegator.admin"), decidim_admin_action_delegator.settings_path,
                        active: is_active_link?(decidim_admin_action_delegator.settings_path),
                        if: allowed_to?(:index, :impersonatable_user)
        end
      end

      initializer "decidim_admin_action_delegator.admin_consultation_menu" do
        Decidim.menu :admin_consultation_menu do |menu|
          menu.remove_item :results_consultation
          is_results = is_active_link?(decidim_admin_consultations.results_consultation_path(current_consultation)) ||
                       is_active_link?(decidim_admin_action_delegator.results_consultation_path(current_consultation)) ||
                       is_active_link?(decidim_admin_action_delegator.weighted_results_consultation_path(current_consultation))
          params = {
            position: 1.2,
            active: is_results,
            if: allowed_to?(:read, :question)
          }
          params[:submenu] = { target_menu: :admin_delegation_results_submenu } if is_results
          menu.add_item :delegated_results,
                        I18n.t("results", scope: "decidim.admin.menu.consultations_submenu"),
                        decidim_admin_consultations.results_consultation_path(current_consultation),
                        params
        end
      end

      initializer "decidim_admin_action_delegator.admin_consultation_menu" do
        Decidim.menu :admin_delegation_results_submenu do |menu|
          menu.add_item :by_answer,
                        I18n.t("by_answer", scope: "decidim.action_delegator.admin.menu.consultations_submenu"),
                        decidim_admin_consultations.results_consultation_path(current_consultation),
                        position: 1.0,
                        active: is_active_link?(decidim_admin_consultations.results_consultation_path(current_consultation)),
                        if: allowed_to?(:read, :question)
          menu.add_item :by_type_and_weight,
                        I18n.t("by_type_and_weight", scope: "decidim.action_delegator.admin.menu.consultations_submenu"),
                        decidim_admin_action_delegator.results_consultation_path(current_consultation),
                        position: 1.1,
                        active: is_active_link?(decidim_admin_action_delegator.results_consultation_path(current_consultation), :exact),
                        if: allowed_to?(:read, :question)
          menu.add_item :sum_of_weights,
                        I18n.t("sum_of_weights", scope: "decidim.action_delegator.admin.menu.consultations_submenu"),
                        decidim_admin_action_delegator.weighted_results_consultation_path(current_consultation),
                        position: 1.2,
                        active: is_active_link?(decidim_admin_action_delegator.weighted_results_consultation_path(current_consultation)),
                        if: allowed_to?(:read, :question)
        end
      end

      def load_seed
        nil
      end
    end
  end
end
