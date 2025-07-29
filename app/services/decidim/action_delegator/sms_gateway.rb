# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class SmsGateway
      attr_reader :mobile_phone_number, :code, :response

      SMS_GATEWAY_PROVIDER_JOBS = {
        som_connexio: SendSmsJob,
        twilio: TwilioSendSmsJob
      }.freeze

      def initialize(mobile_phone_number, code)
        @mobile_phone_number = mobile_phone_number
        @code = code
      end

      def deliver_code
        return false unless sms_gateway_provider_valid?

        sms_gateway_job.perform_later(sender, mobile_phone_number, message)

        true
      end

      private

      def sms_gateway_job
        SMS_GATEWAY_PROVIDER_JOBS[sms_gateway_provider.to_sym]
      end

      def sender
        ENV.fetch("SMS_SENDER", nil)
      end

      def sms_gateway_provider
        ENV.fetch("SMS_GATEWAY_PROVIDER", nil)
      end

      def sms_gateway_provider_valid?
        return false unless sms_gateway_provider

        SMS_GATEWAY_PROVIDER_JOBS.keys.include? sms_gateway_provider.to_sym
      end

      def message
        I18n.t("decidim.action_delegator.sms_message", code: code)
      end
    end
  end
end
