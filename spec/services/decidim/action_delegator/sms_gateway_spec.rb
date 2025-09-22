# frozen_string_literal: true

# require "spec_helper"
#
# module Decidim::ActionDelegator
#   describe SmsGateway do
#     subject { described_class.new(mobile_phone_number, code) }
#
#     let(:mobile_phone_number) { "+12 345 678 901" }
#     let(:code) { "1a4s9b" }
#     let(:response_body) { { send_sms_response: { result: result } } }
#
#     describe "#deliver_code" do
#       before do
#         allow(ENV).to receive(:[]).with("SMS_SENDER").and_return("Amazing app")
#       end
#
#       context "when using som_connexio as provider" do
#         before do
#           allow(ENV).to receive(:[]).with("SMS_GATEWAY_PROVIDER").and_return("som_connexio")
#         end
#
#         it "enqueues a SendSmsJob" do
#           expect { subject.deliver_code }.to have_enqueued_job(SendSmsJob)
#         end
#       end
#
#       context "when using twilio as provider" do
#         before do
#           allow(ENV).to receive(:[]).with("SMS_GATEWAY_PROVIDER").and_return("twilio")
#         end
#
#         it "enqueues a TwilioSendSmsJob" do
#           expect { subject.deliver_code }.to have_enqueued_job(TwilioSendSmsJob)
#         end
#       end
#     end
#   end
# end
