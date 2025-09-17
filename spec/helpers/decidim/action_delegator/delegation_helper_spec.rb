# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::DelegationHelper do
  subject { helper }

  let(:organization) { create(:organization) }
  let(:component) { create(:elections_component, organization: organization) }
  let(:election) do
    create(
      :election,
      :published,
      :ongoing,
      component: component,
      census_manifest: "internal_users",
      census_settings: {
        "authorization_handlers" => {
          "internal_users" => {},
          "delegations_verifier" => {
            "options" => {
              "setting" => setting.id
            }
          }
        }
      }
    )
  end
  let(:user) { create(:user, :confirmed, organization: organization) }
  let(:setting) { create(:setting, organization: organization) }

  describe "#settings_for" do
    subject { helper.settings_for(resource) }

    context "when resource is an Election" do
      let(:resource) { election }

      it "returns ElectionSettings query" do
        expect(subject).to be_a(ActiveRecord::Relation)
        expect(subject.to_sql).to include("decidim_action_delegator_settings")
        expect(subject.count).to eq(1)
        expect(subject.first).to eq(setting)
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization: organization) }

      it "returns Setting.none" do
        expect(subject).to eq(Decidim::ActionDelegator::Setting.none)
        expect(subject.count).to eq(0)
      end
    end
  end

  describe "#delegations_for" do
    subject { helper.delegations_for(resource, user) }

    context "when resource is an Election" do
      let(:resource) { election }
      let!(:delegation) { create(:delegation, setting: setting, grantee: user) }
      let!(:other_delegation) { create(:delegation, setting: setting) }

      it "returns delegations for the user as grantee" do
        expect(subject).to be_a(ActiveRecord::Relation)
        expect(subject.count).to eq(1)
        expect(subject.first).to eq(delegation)
        expect(subject.first.grantee).to eq(user)
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization: organization) }

      it "returns Delegation.none" do
        expect(subject).to eq(Decidim::ActionDelegator::Delegation.none)
        expect(subject.count).to eq(0)
      end
    end
  end

  describe "#participant_voted?" do
    subject { helper.participant_voted?(resource, user) }

    context "when resource is an Election" do
      let(:resource) { election }
      let!(:question) { create(:election_question, :with_response_options, election: election) }

      context "when user has voted" do
        before do
          create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: user.to_global_id.to_s)
        end

        it { is_expected.to be true }
      end

      context "when user has not voted" do
        it { is_expected.to be false }
      end

      context "when user has voted with different voter_uid format" do
        before do
          create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: "different-uid")
        end

        it { is_expected.to be false }
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization: organization) }

      it { is_expected.to be false }
    end
  end
end
