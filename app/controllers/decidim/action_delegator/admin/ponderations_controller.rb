# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class PonderationsController < ActionDelegator::Admin::ApplicationController
        include NeedsPermission
        include Decidim::Paginable

        helper_method :current_setting, :ponderations

        layout "decidim/admin/users"

        def index
          enforce_permission_to :index, :ponderation
        end

        def new
          enforce_permission_to :create, :ponderation

          @form = form(PonderationForm).instance
        end

        def create
          enforce_permission_to :create, :ponderation

          @form = PonderationForm.from_params(params).with_context(setting: current_setting)

          CreatePonderation.call(@form) do
            on(:ok) do
              notice = I18n.t("ponderations.create.success", scope: "decidim.action_delegator.admin")
              redirect_to setting_ponderations_path(current_setting), notice: notice
            end

            on(:invalid) do |_error|
              flash.now[:error] = I18n.t("ponderations.create.error", scope: "decidim.action_delegator.admin")
              render :new
            end
          end
        end

        def edit
          enforce_permission_to :update, :ponderation

          @form = form(PonderationForm).from_model(ponderation)
        end

        def update
          enforce_permission_to :update, :ponderation

          @form = PonderationForm.from_params(params).with_context(setting: current_setting)
          UpdatePonderation.call(@form, ponderation) do
            on(:ok) do
              notice = I18n.t("ponderations.update.success", scope: "decidim.action_delegator.admin")
              redirect_to setting_ponderations_path(current_setting), notice: notice
            end

            on(:invalid) do |_error|
              flash.now[:error] = I18n.t("ponderations.update.error", scope: "decidim.action_delegator.admin")
              render :edit
            end
          end
        end

        def destroy
          enforce_permission_to :destroy, :ponderation, resource: ponderation

          if ponderation.destroy
            notice = I18n.t("ponderations.destroy.success", scope: "decidim.action_delegator.admin")
            redirect_to setting_ponderations_path(current_setting), notice: notice
          else
            error = I18n.t("ponderations.destroy.error", scope: "decidim.action_delegator.admin")
            redirect_to setting_ponderations_path(current_setting), flash: { error: error }
          end
        end

        private

        def ponderation
          @ponderation ||= collection.find_by(id: params[:id])
        end

        def ponderations
          @ponderations ||= paginate(collection)
        end

        def collection
          @collection ||= current_setting.ponderations
        end
      end
    end
  end
end
