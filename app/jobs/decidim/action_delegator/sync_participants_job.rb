# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class SyncParticipantsJob < ApplicationJob
      queue_as :default

      def perform(setting)
        @setting = setting

        return unless setting&.participants

        setting.participants.each(&:save)
      end

      private

      attr_reader :setting
    end
  end
end
