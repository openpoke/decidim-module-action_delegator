# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class SettingsController < ActionDelegator::Admin::ApplicationController
        helper ::Decidim::ActionDelegator::Admin::DelegationHelper
        include Filterable
        include Paginable

        layout "decidim/admin/users"
        helper_method :settings, :settings_select_options, :copy_from_setting

        def index
          enforce_permission_to :index, :setting
        end

        def new
          enforce_permission_to :create, :setting

          @form = form(SettingForm).instance
        end

        def create
          enforce_permission_to :create, :setting

          @form = form(SettingForm).from_params(params)

          CreateSetting.call(@form, copy_from_setting) do
            on(:ok) do
              notice = I18n.t("settings.create.success", scope: "decidim.action_delegator.admin")
              redirect_to decidim_admin_action_delegator.settings_path, notice: notice
            end

            on(:invalid) do |_error|
              flash.now[:error] = I18n.t("settings.create.error", scope: "decidim.action_delegator.admin")
              render :new
            end
          end
        end

        def edit
          enforce_permission_to :update, :setting

          @form = form(SettingForm).from_model(setting)
        end

        def update
          enforce_permission_to :update, :setting

          @form = form(SettingForm).from_params(params)

          UpdateSetting.call(@form, setting, copy_from_setting) do
            on(:ok) do
              notice = I18n.t("settings.update.success", scope: "decidim.action_delegator.admin")
              redirect_to decidim_admin_action_delegator.settings_path, notice: notice
            end

            on(:invalid) do |_error|
              flash.now[:error] = I18n.t("settings.update.error", scope: "decidim.action_delegator.admin")
              render :edit
            end
          end
        end

        def destroy
          enforce_permission_to :destroy, :setting, resource: setting

          if setting.destroy
            flash[:notice] = I18n.t("settings.destroy.success", scope: "decidim.action_delegator.admin")
          else
            flash[:error] = I18n.t("settings.destroy.error", scope: "decidim.action_delegator.admin")
          end

          redirect_to settings_path
        end

        private

        def setting_params
          params.require(:setting).permit(:max_grants)
        end

        def build_setting
          Setting.new(setting_params)
        end

        def setting
          @setting ||= collection.find_by(id: params[:id])
        end

        def settings
          @settings ||= paginate(collection)
        end

        def collection
          @collection ||= ActionDelegator::OrganizationSettings.new(current_organization).query
        end

        def settings_select_options
          collection.to_h { |setting| [setting.resource.id, translated_attribute(setting.title)] }
        end

        def copy_from_setting
          @copy_from_setting ||= Setting.find_by(resource_id: params[:setting][:copy_from_setting_id], resource_type: params[:setting][:resource_type])
        end
      end
    end
  end
end
