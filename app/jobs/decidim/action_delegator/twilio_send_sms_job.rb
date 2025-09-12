# frozen_string_literal: true

require "twilio-ruby"

module Decidim
  module ActionDelegator
    class TwilioSendSmsJob < ApplicationJob
      queue_as :default

      def perform(sender, mobile_phone_number, message)
        @sender = sender
        @mobile_phone_number = mobile_phone_number
        @message = message

        send_sms!
      end

      private

      attr_reader :sender, :mobile_phone_number, :message

      def send_sms!
        client.messages.create(
          from: sender,
          to: mobile_phone_number,
          body: message
        )
      end

      def client
        ::Twilio::REST::Client.new twilio_account_sid, twilio_auth_token
      end

      def twilio_account_sid
        ENV.fetch("TWILIO_ACCOUNT_SID", nil)
      end

      def twilio_auth_token
        ENV.fetch("TWILIO_AUTH_TOKEN", nil)
      end
    end
  end
end
