# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class DelegationsController < ActionDelegator::Admin::ApplicationController
        include NeedsPermission
        include Paginable

        helper ::Decidim::ActionDelegator::Admin::SettingsHelper
        helper_method :current_setting, :delegations

        layout "decidim/admin/users"

        def index
          enforce_permission_to :index, :delegation
        end

        def new
          enforce_permission_to :create, :delegation

          @form = form(DelegationForm).instance
        end

        def create
          enforce_permission_to :create, :delegation

          @form = form(DelegationForm).from_params(params)

          CreateDelegation.call(@form, current_user, current_setting) do
            on(:ok) do
              notice = I18n.t("delegations.create.success", scope: "decidim.action_delegator.admin")
              redirect_to setting_delegations_path(current_setting), notice: notice
            end

            on(:error) do |error|
              flash.now[:error] = error
              render :new
            end
          end
        end

        def destroy
          enforce_permission_to :destroy, :delegation, resource: delegation

          if delegation.destroy
            notice = I18n.t("delegations.destroy.success", scope: "decidim.action_delegator.admin")
            redirect_to setting_delegations_path(current_setting), notice: notice
          else
            error = I18n.t("delegations.destroy.error", scope: "decidim.action_delegator.admin")
            redirect_to setting_delegations_path(current_setting), flash: { error: error }
          end
        end

        def users
          relation = current_organization.users.available
          respond_to do |format|
            format.json do
              if (term = params[:term].to_s).present?
                query = if term.start_with?("@")
                          nickname = term.delete("@")
                          relation.where("nickname LIKE ?", "#{nickname}%")
                                  .order(Arel.sql(ActiveRecord::Base.sanitize_sql_array("similarity(nickname, '#{nickname}') DESC")))
                        else
                          relation.where("name ILIKE ?", "%#{term}%").or(
                            relation.where("email ILIKE ?", "%#{term}%")
                          )
                                  .order(Arel.sql(ActiveRecord::Base.sanitize_sql_array("GREATEST(similarity(name, '#{term}'), similarity(email, '#{term}')) DESC")))
                                  .order(Arel.sql(ActiveRecord::Base.sanitize_sql_array("(similarity(name, '#{term}') + similarity(email, '#{term}')) / 2 DESC")))
                        end
                render json: query.all.collect { |u| { value: u.id, label: "#{u.name} (@#{u.nickname} - #{u.email})" } }
              else
                render json: []
              end
            end
          end
        end

        private

        def delegation
          @delegation ||= collection.find_by(id: params[:id])
        end

        def delegations
          @delegations ||= paginate(collection)
        end

        def collection
          @collection ||= Delegation.where(setting: current_setting)
        end
      end
    end
  end
end
