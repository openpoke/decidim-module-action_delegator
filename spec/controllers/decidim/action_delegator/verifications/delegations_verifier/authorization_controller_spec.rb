# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Verifications
      module DelegationsVerifier
        describe AuthorizationsController do
          routes { Decidim::ActionDelegator::Verifications::DelegationsVerifier::Engine.routes }

          let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier)) }
          let(:user) { create(:user, :confirmed, organization: organization) }
          let(:consultation) { create(:consultation, organization: organization) }
          let(:setting) { create(:setting, authorization_method: method, consultation: consultation) }
          let(:method) { :email }
          let!(:participant) { create(:participant, setting: setting, decidim_user: decidim_user, email: email, phone: phone) }
          let(:decidim_user) { create(:user, organization: organization) }
          let(:email) { user.email }
          let(:phone) { "1234" }
          let(:params) do
            {
              email: email,
              phone: phone
            }
          end

          before do
            request.env["decidim.current_organization"] = organization
            sign_in user
          end

          shared_examples "does not verify" do
            it "does not authorize the user" do
              expect(Decidim::Authorization.last).to be_nil
              expect(participant.decidim_user).not_to eq(user)

              post :create, params: params

              expect(response).to have_http_status(:ok)
              expect(response).to render_template(:new)
              expect(flash.alert).to include("There was a problem with your request")

              expect(Decidim::Authorization.last).to be_nil
              expect(participant.reload.decidim_user).not_to eq(user)
            end
          end

          shared_examples "verifies by email" do
            it "authorizes the user" do
              expect(Decidim::Authorization.last).to be_nil
              expect(participant.decidim_user).not_to eq(user)

              post :create, params: params

              expect(response).to have_http_status(:redirect)
              expect(flash.notice).to include("You've been successfully verified")

              expect(Decidim::Authorization.last).to be_granted
              expect(participant.reload.decidim_user).to eq(user)
            end
          end

          shared_examples "verifies by SMS" do
            it "sends an sms" do
              expect(Decidim::Authorization.last).to be_nil
              expect(participant.decidim_user).not_to eq(user)

              post :create, params: params

              expect(response).to have_http_status(:redirect)
              expect(flash.notice).to include("Thanks! We've sent an SMS to your phone")

              expect(Decidim::Authorization.last).not_to be_granted
              expect(participant.reload.decidim_user).not_to eq(user)
            end
          end

          describe "post #create" do
            it_behaves_like "verifies by email"

            context "when authorization method is phone" do
              let(:method) { :phone }

              it_behaves_like "verifies by SMS"
            end

            context "when authorization method is both" do
              let(:method) { :both }

              it_behaves_like "verifies by SMS"
            end

            context "when participant is not found" do
              let(:email) { "foo" }

              it_behaves_like "does not verify"
            end
          end
        end
      end
    end
  end
end
