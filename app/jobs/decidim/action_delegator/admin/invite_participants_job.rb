# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class InviteParticipantsJob < ApplicationJob
        queue_as :invite_participants

        def perform(current_setting, organization)
          @current_setting = current_setting
          @organization = organization

          users_list_to_invite.find_each do |participant|
            form = InvitationParticipantForm.new(
              name: participant.email.split("@").first&.gsub(/\W/, ""),
              email: participant.email.downcase,
              organization: organization,
              admin: false
            )

            Decidim::InviteUser.call(form)
          end
        end

        private

        def users_list_to_invite
          @users_list_to_invite ||= @current_setting.participants.where(decidim_user: nil)
                                                    .where.not(email: @organization.users.select(:email))
                                                    .where.not("MD5(CONCAT(phone::text, '-', CAST(? AS text), '-', CAST(? AS text))) IN (?)",
                                                               @organization.id,
                                                               Digest::MD5.hexdigest(Rails.application.secret_key_base),
                                                               Authorization.select(:unique_id)
                                                                            .where.not(unique_id: nil))
        end
      end
    end
  end
end
