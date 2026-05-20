# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe ElectionCensusUsers do
      let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier dummy_authorization_workflow)) }
      let(:election) { create(:election, component: component, census_manifest: census_manifest, census_settings: census_settings) }
      let(:census_manifest) { "action_delegator_census" }
      let(:census_settings) do
        {
          "setting_id" => setting.id.to_s,
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {}
            }
          }
        }
      end
      let(:component) { create(:elections_component, organization: organization) }
      let!(:setting) { create(:setting, max_grants: 2, organization: organization) }
      let!(:user_unconfirmed) { create(:user, organization: organization) }
      let!(:user_confirmed) { create(:user, :confirmed, organization: organization) }
      let!(:user_blocked) { create(:user, :blocked, organization: organization) }
      let!(:user_deleted) { create(:user, :deleted, organization: organization) }
      let!(:user_in_other_org) { create(:user) }
      let!(:user_in_participants) { create(:user, :confirmed, organization: organization) }
      let!(:granter_user_authorized_without_authorization) { create(:user, :confirmed, organization: organization) }
      let!(:granter_user_unauthorized) { create(:user, :confirmed, organization: organization) }
      let!(:grantee_user_unauthorized) { create(:user, :confirmed, organization: organization) }
      let!(:grantee_user_authorized) { create(:user, :confirmed, organization: organization) }
      let!(:user_authorized_by_dummy) { create(:user, :confirmed, organization: organization) }
      let!(:user_authorized_by_dummy_invalid) { create(:user, :confirmed, organization: organization) }
      let!(:user_authorized_by_delegations) { create(:user, :confirmed, organization: organization) }
      let!(:user_authorized_by_both) { create(:user, :confirmed, organization: organization) }
      let!(:authorization_dummy) { create(:authorization, user: user_authorized_by_dummy, name: "dummy_authorization_workflow", metadata: { "postal_code" => "08001" }) }
      let!(:authorization_dummy_invalid) { create(:authorization, user: user_authorized_by_dummy_invalid, name: "dummy_authorization_workflow", metadata: { "postal_code" => "08002" }) }
      let!(:authorization_delegations) { create(:authorization, user: user_authorized_by_delegations, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }
      let!(:authorization_both_dummy) { create(:authorization, user: user_authorized_by_both, name: "dummy_authorization_workflow", metadata: { "postal_code" => "08001" }) }
      let!(:authorization_both_delegations) { create(:authorization, user: user_authorized_by_both, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }
      let!(:authorization_grantee) { create(:authorization, user: grantee_user_authorized, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }
      let!(:participant) { create(:participant, setting: setting, decidim_user: user_in_participants) }
      let!(:delegation_authorized) { create(:delegation, setting: setting, grantee: grantee_user_authorized, granter: granter_user_authorized_without_authorization) }
      let!(:delegation_unauthorized) { create(:delegation, setting: setting, grantee: grantee_user_unauthorized, granter: granter_user_unauthorized) }
      let!(:authorization_unconfirmed) { create(:authorization, user: user_unconfirmed, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }
      let!(:authorization_blocked) { create(:authorization, user: user_blocked, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }
      let!(:authorization_deleted) { create(:authorization, user: user_deleted, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }

      subject { described_class.new(election).query }

      context "when election is not using action_delegator_census" do
        let(:census_manifest) { "internal_users" }
        let(:census_settings) { {} }

        it "returns none of the users" do
          expect(subject.count).to eq(0)
        end
      end

      context "when election has an incorrect setting_id" do
        let(:census_settings) do
          {
            "setting_id" => "0",
            "authorization_handlers" => {}
          }
        end

        it "returns none of the users" do
          expect(subject.count).to eq(0)
        end
      end

      context "without other authorization handlers" do
        it "returns users from the verifier and delegations" do
          expect(subject).not_to include(user_in_participants)
          expect(subject).to include(user_authorized_by_delegations)
          expect(subject).not_to include(user_authorized_by_dummy)
          expect(subject).not_to include(user_authorized_by_dummy_invalid)
          expect(subject).to include(user_authorized_by_both)
          expect(subject).not_to include(user_in_other_org)
          expect(subject).not_to include(user_unconfirmed)
          expect(subject).not_to include(user_blocked)
          expect(subject).not_to include(user_deleted)
          expect(subject).not_to include(grantee_user_unauthorized)
          expect(subject).to include(grantee_user_authorized)
          expect(subject).to include(granter_user_authorized_without_authorization)
          expect(subject).not_to include(granter_user_unauthorized)
        end

        context "when user in participants has an authorization" do
          let!(:authorization_participant) { create(:authorization, user: user_in_participants, name: "delegations_verifier", metadata: { "setting" => [setting.id] }) }

          it "returns users from the verifier and delegations" do
            expect(subject).to include(user_in_participants)
            expect(subject).to include(user_authorized_by_delegations)
          end
        end

        context "when user in participants has an invalid authorization" do
          let!(:authorization_participant) { create(:authorization, user: user_in_participants, name: "delegations_verifier", metadata: { "setting" => ["0"] }) }

          it "returns users from the verifier and delegations" do
            # Note that this is correct as the final check is done by the authorizer adapter
            expect(subject).to include(user_in_participants)
            expect(subject).to include(user_authorized_by_delegations)
          end
        end
      end

      context "with another authorization handler" do
        let(:census_settings) do
          {
            "setting_id" => setting.id.to_s,
            "authorization_handlers" => {
              "dummy_authorization_workflow" => {
                "options" => {
                  "postal_code" => "08001"
                }
              }
            }
          }
        end

        it "returns users authorized by that handler" do
          expect(subject).to include(user_authorized_by_dummy)
          # this is correct as the final check is done by the authorizer adapter
          expect(subject).to include(user_authorized_by_dummy_invalid)
          expect(subject).to include(user_authorized_by_both)
        end
      end

      context "with both authorization handlers" do
        let(:census_settings) do
          {
            "setting_id" => setting.id.to_s,
            "authorization_handlers" => {
              "dummy_authorization_workflow" => {
                "options" => {
                  "postal_code" => "08001"
                }
              },
              "delegations_verifier" => {
                "options" => {}
              }
            }
          }
        end

        it "returns users authorized by all of the handlers" do
          expect(subject).not_to include(user_authorized_by_dummy)
          expect(subject).not_to include(user_authorized_by_dummy_invalid)
          expect(subject).not_to include(user_authorized_by_delegations)
          expect(subject).to include(user_authorized_by_both)
        end
      end

      context "without authorization handlers" do
        let(:census_settings) do
          {
            "setting_id" => setting.id.to_s,
            "authorization_handlers" => {}
          }
        end

        it "returns all confirmed users" do
          expect(subject).to include(user_confirmed)
          expect(subject).not_to include(user_unconfirmed)
          expect(subject).not_to include(user_blocked)
          expect(subject).not_to include(user_deleted)
          expect(subject).not_to include(user_in_other_org)
          expect(subject).to include(user_authorized_by_dummy)
          expect(subject).to include(user_authorized_by_dummy_invalid)
          expect(subject).to include(user_authorized_by_delegations)
          expect(subject).to include(user_authorized_by_both)
          expect(subject).to include(grantee_user_authorized)
          expect(subject).to include(granter_user_authorized_without_authorization)
          expect(subject).to include(granter_user_unauthorized)
          expect(subject).to include(user_in_participants)
        end
      end
    end
  end
end
