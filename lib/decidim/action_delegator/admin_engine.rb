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

      initializer "decidim_admin_action_delegator.admin_user_menu" do
        Decidim.menu :admin_user_menu do |menu|
          menu.add_item :action_delegator,
                        I18n.t("menu.delegations", scope: "decidim.action_delegator.admin"), decidim_admin_action_delegator.settings_path,
                        active: is_active_link?(decidim_admin_action_delegator.settings_path),
                        icon_name: "government-line",
                        if: allowed_to?(:index, :impersonatable_user)
        end
      end

      initializer "decidim_elections_admin.menu" do
        Decidim.menu :admin_action_delegator_menu do |menu|
          menu.add_item :setting_main,
                        I18n.t("main", scope: "decidim.action_delegator.admin.menu.action_delegator_menu"),
                        current_setting ? decidim_admin_action_delegator.edit_setting_path(current_setting) : decidim_admin_action_delegator.new_setting_path,
                        icon_name: "bill-line",
                        active: is_active_link?(decidim_admin_action_delegator.new_setting_path) ||
                                (current_setting && is_active_link?(decidim_admin_action_delegator.edit_setting_path(current_setting)))

          menu.add_item :setting_ponderations,
                        I18n.t("ponderations", scope: "decidim.action_delegator.admin.menu.action_delegator_menu"),
                        current_setting ? decidim_admin_action_delegator.setting_ponderations_path(current_setting) : "#",
                        icon_name: "scales-line",
                        active: current_setting && is_active_link?(decidim_admin_action_delegator.setting_ponderations_path(current_setting))

          menu.add_item :setting_participants,
                        I18n.t("participants", scope: "decidim.action_delegator.admin.menu.action_delegator_menu"),
                        current_setting ? decidim_admin_action_delegator.setting_participants_path(current_setting) : "#",
                        icon_name: "group-line",
                        active: current_setting && (is_active_link?(decidim_admin_action_delegator.setting_participants_path(current_setting)) ||
                                                    is_active_link?(decidim_admin_action_delegator.new_setting_participant_path(current_setting)) ||
                                                    is_active_link?(decidim_admin_action_delegator.new_setting_manage_participant_path(current_setting)) ||
                                                    (@participant && is_active_link?(decidim_admin_action_delegator.edit_setting_participant_path(current_setting, @participant))))

          menu.add_item :setting_delegations,
                        I18n.t("delegations", scope: "decidim.action_delegator.admin.menu.action_delegator_menu"),
                        current_setting ? decidim_admin_action_delegator.setting_delegations_path(current_setting) : "#",
                        icon_name: "user-shared-line",
                        active: current_setting && (is_active_link?(decidim_admin_action_delegator.setting_delegations_path(current_setting)) ||
                                                    is_active_link?(decidim_admin_action_delegator.new_setting_delegation_path(current_setting)) ||
                                                    is_active_link?(decidim_admin_action_delegator.new_setting_manage_delegation_path(current_setting)))
        end
      end

      initializer "decidim_admin_action_delegator.admin_election_menu" do
        Decidim.menu :admin_election_menu do |menu|
          menu.remove_item :results_election
          is_results = is_active_link?(decidim_admin_elections.results_election_path(current_election)) ||
                       is_active_link?(decidim_admin_action_delegator.results_election_path(current_election)) ||
                       is_active_link?(decidim_admin_action_delegator.weighted_results_election_path(current_election))
          params = {
            position: 1.2,
            active: is_results,
            if: allowed_to?(:read, :question)
          }
          params[:submenu] = { target_menu: :admin_delegation_results_submenu } if is_results
          menu.add_item :delegated_results,
                        I18n.t("results", scope: "decidim.admin.menu.elections_submenu"),
                        decidim_admin_elections.results_election_path(current_election),
                        params
        end
      end

      initializer "decidim_admin_action_delegator.admin_election_menu" do
        Decidim.menu :admin_delegation_results_submenu do |menu|
          election = @election
          current_component_admin_proxy = election ? Decidim::EngineRouter.admin_proxy(election.component) : nil

          menu.add_item :by_answer,
                        I18n.t("by_answer", scope: "decidim.action_delegator.admin.menu.elections_submenu"),
                        @election.present? && @election.census_ready? ? current_component_admin_proxy&.dashboard_election_path(@election) : "#",
                        active: @election.present? ? is_active_link?(current_component_admin_proxy&.dashboard_election_path(@election)) : false,
                        icon_name: "list-check",
                        active: :exact
          menu.add_item :by_type_and_weight,
                        I18n.t("by_type_and_weight", scope: "decidim.action_delegator.admin.menu.elections_submenu"),
                        @election.present? && @election.census_ready? ? current_component_admin_proxy&.dashboard_election_path(@election, results: :by_type_and_weight) : "#",
                        active: @election.present? ? is_active_link?(current_component_admin_proxy&.dashboard_election_path(@election, results: :by_type_and_weight)) : false,
                        icon_name: "list-check-2",
                        active: :exact
          menu.add_item :sum_of_weights,
                        I18n.t("sum_of_weights", scope: "decidim.action_delegator.admin.menu.elections_submenu"),
                        @election.present? && @election.census_ready? ? current_component_admin_proxy&.dashboard_election_path(@election, results: :sum_of_weights) : "#",
                        active: @election.present? ? is_active_link?(current_component_admin_proxy&.dashboard_election_path(@election, results: :sum_of_weights)) : false,
                        icon_name: "bar-chart-2-line",
                        active: :exact
          menu.add_item :totals,
                        I18n.t("totals", scope: "decidim.action_delegator.admin.menu.elections_submenu"),
                        @election.present? && @election.census_ready? ? current_component_admin_proxy&.dashboard_election_path(@election, results: :totals) : "#",
                        active: @election.present? ? is_active_link?(current_component_admin_proxy&.dashboard_election_path(@election, results: :totals)) : false,
                        icon_name: "scales-line",
                        active: :exact
        end
      end

      def load_seed
        nil
      end
    end
  end
end
