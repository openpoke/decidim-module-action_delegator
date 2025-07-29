# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class InviteParticipantsController < ActionDelegator::Admin::ApplicationController
        include NeedsPermission

        before_action :enforce_permission_to_invite

        helper_method :current_setting, :participant, :form

        def invite_user
          enforce_permission_to :invite, :participant, resource: current_setting

          Decidim::InviteUser.call(form) do
            on(:ok) do
              notice = t("invite_user.success", scope: "decidim.action_delegator.admin.invite_participants")
              redirect_to decidim_admin_action_delegator.setting_participants_path(current_setting), notice: notice
            end
          end
        end

        def invite_all_users
          enforce_permission_to :invite, :participant, resource: current_setting

          InviteParticipantsJob.perform_later(current_setting, current_organization)

          notice = t("invite_all_users.success", scope: "decidim.action_delegator.admin.invite_participants")
          redirect_to decidim_admin_action_delegator.setting_participants_path(current_setting), notice: notice
        end

        def resend_invitation
          enforce_permission_to :invite, :participant, resource: current_setting

          Decidim::InviteUserAgain.call(participant.user, "invitation_instructions") do
            on(:ok) do
              flash[:notice] = I18n.t("users.resend_invitation.success", scope: "decidim.admin")
            end

            redirect_to setting_participants_path(current_setting)
          end
        end

        private

        def participants
          @participants ||= current_setting.participants
        end

        def participant
          @participant ||= participants.find_by(id: params[:id])
        end

        def build_form(participant)
          Decidim::ActionDelegator::Admin::InvitationParticipantForm.new(
            name: participant.email.split("@").first&.gsub(/\W/, ""),
            email: participant.email.downcase,
            organization: current_organization,
            admin: false,
            invited_by: current_user
          )
        end

        def form
          @form ||= build_form(participant)
        end

        def enforce_permission_to_invite
          alert = t("permissions.not_allowed", scope: "decidim.action_delegator.admin.invite_participants")
          redirect_to setting_participants_path(current_setting), alert: alert unless Decidim::ActionDelegator.allow_to_invite_users
        end
      end
    end
  end
end
