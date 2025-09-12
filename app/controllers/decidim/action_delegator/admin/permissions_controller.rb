# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class PermissionsController < ActionDelegator::Admin::ApplicationController
        def sync
          enforce_permission_to :update, :setting

          SyncParticipantsJob.perform_later(current_setting)
          notice = I18n.t("permissions.sync.started", scope: "decidim.action_delegator.admin")
          redirect_to decidim_admin_action_delegator.settings_path, notice: notice
        end
      end
    end
  end
end
