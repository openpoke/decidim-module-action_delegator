# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Setting do
      subject { build(:setting, authorization_method: authorization_method) }

      let(:authorization_method) { :email }
      let(:start_voting_date) { 1.day.ago }
      let(:end_voting_date) { 1.day.from_now }

      it { is_expected.to have_many(:delegations).dependent(:restrict_with_error) }
      it { is_expected.to have_many(:ponderations).dependent(:restrict_with_error) }
      it { is_expected.to have_many(:participants).dependent(:restrict_with_error) }
      it { is_expected.to validate_presence_of(:max_grants) }
      it { is_expected.to validate_numericality_of(:max_grants).is_greater_than(0) }

      it "returns the title" do
        expect(subject.title).to be_present
        expect(subject.description).to be_present
      end

      context "when destroyed" do
        before do
          subject.save!
        end

        it "can be destroyed" do
          expect { subject.destroy }.to change(Setting, :count).by(-1)
        end

        shared_examples "cannot be destroyed" do
          it "does not destroy" do
            expect { subject.destroy }.not_to change(Setting, :count)
          end
        end

        context "when has participants" do
          before do
            create(:participant, setting: subject)
          end

          it_behaves_like "cannot be destroyed"
        end

        context "when has ponderations" do
          before do
            create(:ponderation, setting: subject)
          end

          it_behaves_like "cannot be destroyed"
        end

        context "when has delegations" do
          before do
            create(:delegation, setting: subject)
          end

          it_behaves_like "cannot be destroyed"
        end
      end

      describe "#elections" do
        let(:setting) { create(:setting) }
        let(:component) { create(:elections_component, organization: setting.organization) }
        let!(:other_setting) { create(:setting, organization: setting.organization) }

        let!(:corporate_census_election) do
          create(
            :election,
            :published,
            component:,
            census_manifest: "action_delegator_census",
            census_settings: { "setting_id" => setting.id.to_s, "authorization_handlers" => {} }
          )
        end
        let!(:registered_census_election) do
          create(
            :election,
            :published,
            component:,
            census_manifest: "internal_users",
            census_settings: {
              "authorization_handlers" => {
                "delegations_verifier" => { "options" => { "setting" => setting.id.to_s } }
              }
            }
          )
        end
        let!(:other_setting_election) do
          create(
            :election,
            :published,
            component:,
            census_manifest: "action_delegator_census",
            census_settings: { "setting_id" => other_setting.id.to_s, "authorization_handlers" => {} }
          )
        end

        it "returns elections that use this setting as a Corporate Governance Census" do
          expect(setting.elections).to include(corporate_census_election)
        end

        it "returns elections that use this setting as the option of the Delegations Verifier" do
          expect(setting.elections).to include(registered_census_election)
        end

        it "does not return elections bound to a different setting" do
          expect(setting.elections).not_to include(other_setting_election)
        end

        it "memoizes the result" do
          first_call = setting.elections
          expect(setting.elections).to be(first_call)
        end
      end
    end
  end
end
