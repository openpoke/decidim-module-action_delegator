# frozen_string_literal: true

require "spec_helper"

module Decidim::ActionDelegator
  describe SendSmsJob do
    subject { described_class }

    let(:sender) { "Sender" }
    let(:mobile_phone_number) { "+12 345 6789" }
    let(:message) { "A very important message" }

    let(:client) { double("client") }
    let(:response) { double("response") }
    let(:response_body) { { send_sms_response: { result: } } }

    describe "queue" do
      it "is queued to default" do
        expect(subject.queue_name).to eq "default"
      end
    end

    describe "#perform" do
      before do
        allow(Savon).to receive(:client).and_return(client)
        allow(client).to receive(:call).and_return(response)
        allow(response).to receive(:body).and_return(response_body)
      end

      context "when code's result is 200" do
        let(:result) { "<xml><codigo>200</codigo><descripcion>Went well</descripcion></xml>" }

        it "Does not raise SendSmsJobException" do
          expect { subject.perform_now(sender, mobile_phone_number, message) }.not_to raise_error
        end
      end

      context "when code's result isn't 200" do
        let(:result) { "<xml><codigo>115</codigo><descripcion>Woopsie</descripcion></xml>" }

        it "Raises SendSmsJobException" do
          expect { subject.perform_now(sender, mobile_phone_number, message) }.to raise_error(SendSmsJobException)
        end
      end
    end
  end
end
