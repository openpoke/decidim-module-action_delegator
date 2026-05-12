# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class SyncParticipantsJob < ApplicationJob
      queue_as :default

      def perform(setting)
        @setting = setting

        return unless setting&.participants

        setting.participants.where(decidim_user_id: nil).find_each do |participant|
          next if participant.save

          Rails.logger.warn(
            "SyncParticipantsJob failed to save participant #{participant.id}: #{participant.errors.full_messages.to_sentence}"
          )
        end
      end

      private

      attr_reader :setting
    end
  end
end
