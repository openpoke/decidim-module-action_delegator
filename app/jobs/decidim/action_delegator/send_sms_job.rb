# frozen_string_literal: true

require "savon"

module Decidim
  module ActionDelegator
    class SendSmsJobException < StandardError; end

    class SendSmsJob < ApplicationJob
      queue_as :default

      SMSVIRTUAL_WSDL_URL = "https://websms.masmovil.com/api_php/smsvirtual.wsdl"

      def perform(sender, mobile_phone_number, message)
        @sender = sender
        @mobile_phone_number = mobile_phone_number
        @message = message

        send_sms!

        raise SendSmsJobException, response unless success?
      end

      private

      attr_reader :sender, :mobile_phone_number, :message, :response

      def send_sms!
        @response = client.call(:send_sms,
                                message: {
                                  user: ENV.fetch("SMS_USER", nil),
                                  pass: ENV.fetch("SMS_PASS", nil),
                                  src: sender,
                                  dst: mobile_phone_number,
                                  msg: message
                                })
      end

      def success?
        parsed_response[:code] == "200"
      end

      def client
        @client ||= ::Savon.client(wsdl: SMSVIRTUAL_WSDL_URL)
      end

      def parsed_response
        return @parsed_response if @parsed_response

        doc = Nokogiri::XML response.body[:send_sms_response][:result]

        @parsed_response = {
          code: doc.xpath("//codigo").text,
          description: doc.xpath("//descripcion").text
        }

        @parsed_response
      end
    end
  end
end
