# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe ActionAuthorizer do
    subject { authorizer }

    let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier)) }
    let(:start_voting_date) { 1.day.ago }
    let(:end_voting_date) { 1.day.from_now }
    let(:user) { create(:user, organization: organization) }
    let(:consultation) { create(:consultation, organization: organization, start_voting_date: start_voting_date, end_voting_date: end_voting_date) }
    let(:question) { create(:question, consultation: consultation) }
    let(:component) { create(:component, permissions: permissions, organization: organization, participatory_space: consultation) }
    let(:resource) { nil }
    let(:action) { "vote" }
    let(:permissions) { { action => permission } }
    let(:authorizer) { described_class.new(user, action, component, resource) }
    let(:setting) { create(:setting) }
    let(:email) { user.email }
    let(:phone) { "123456" }
    let(:authorization_method) { :email }

    let!(:authorization) do
      create(:authorization, :granted, user: user, name: "delegations_verifier", metadata: metadata)
    end

    let(:metadata) { {} }

    let(:response) { subject.authorize }

    let(:permission) do
      {
        "authorization_handlers" => {
          "delegations_verifier" => { "options" => options }
        }
      }
    end

    let(:options) { {} }
    let(:explanations) { ["no_setting"] }

    shared_examples "unauthorized" do
      it "returns unauthorized" do
        expect(response).not_to be_ok
        expect(response.codes).to include(:unauthorized)
        expect(response.statuses.first.data[:extra_explanation].pluck(:key)).to match_array(explanations)
      end
    end

    shared_examples "pending" do
      it "returns pending" do
        expect(response).not_to be_ok
        expect(response.codes).to include(:pending)
      end
    end

    shared_examples "authorized" do
      it "returns ok" do
        expect(response).to be_ok
      end
    end

    context "when no settings are set" do
      it_behaves_like "unauthorized"
    end

    context "when there are settings" do
      let!(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
      let(:explanations) { %w(not_in_census email) }
      let!(:participants) { [create(:participant, email: email, phone: phone, setting: setting, decidim_user: decidim_user)] }
      let(:decidim_user) { create(:user, organization: organization) }
      let!(:ponderations) { create_list(:ponderation, 2, setting: setting) }

      it_behaves_like "authorized"

      context "and is not the same consultation" do
        let(:explanations) { ["no_setting"] }
        let(:other_consultation) { create(:consultation, organization: organization) }
        let(:component) { create(:component, permissions: permissions, organization: organization, participatory_space: other_consultation) }

        it_behaves_like "unauthorized"
      end

      context "and is in another participatory space" do
        let(:other_consultation) { create(:consultation, organization: organization) }
        let(:participatory_process) { create(:participatory_process, organization: organization) }
        let(:component) { create(:component, permissions: permissions, organization: organization, participatory_space: participatory_process) }

        it_behaves_like "authorized"
      end

      context "and authorization is not granted" do
        before { authorization.update!(user: user, granted_at: nil) }

        it_behaves_like "pending"
      end

      context "and user is not in the list of participants" do
        let(:email) { "other_email" }

        it_behaves_like "unauthorized"

        context "and decidim user is" do
          let(:decidim_user) { user }

          it_behaves_like "authorized"
        end
      end

      context "when phone is required and fixed" do
        let(:authorization_method) { :both }
        let(:metadata) { { "phone" => phone } }

        it_behaves_like "authorized"

        context "and phone is not the same" do
          let(:metadata) { { "phone" => "another_phone" } }
          let(:explanations) { %w(not_in_census email phone) }

          it_behaves_like "unauthorized"
        end
      end
    end
  end
end
