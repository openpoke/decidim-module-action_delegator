# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::SettingsHelper do
  subject { helper }

  let(:organization) { create(:organization) }
  let(:setting) { create(:setting, :with_ponderations, organization:) }
  let!(:user1) { create(:user, :confirmed, organization:) }
  let!(:user2) { create(:user, :confirmed, organization:) }
  let!(:participant1) { create(:participant, setting:, email: user1.email, phone: "+34666666666") }
  let!(:participant2) { create(:participant, setting:, phone: "+34777777777") }

  before do
    allow(helper).to receive(:current_organization).and_return(organization)
  end

  describe "#granters_for_select" do
    it "returns all users from current organization" do
      result = helper.granters_for_select

      expect(result).to include(user1, user2)
      expect(result.count).to eq(organization.users.count)
    end
  end

  describe "#grantees_for_select" do
    it "returns all users from current organization" do
      result = helper.grantees_for_select

      expect(result).to include(user1, user2)
      expect(result.count).to eq(organization.users.count)
    end
  end

  describe "#ponderations_for_select" do
    it "returns array of ponderation titles and ids" do
      result = helper.ponderations_for_select(setting)

      expect(result).to be_an(Array)
      expect(result.length).to eq(setting.ponderations.count)

      setting.ponderations.each do |ponderation|
        expect(result).to include([ponderation.title, ponderation.id])
      end
    end

    context "when setting has no ponderations" do
      let(:empty_setting) { create(:setting, organization:) }

      it "returns empty array" do
        result = helper.ponderations_for_select(empty_setting)
        expect(result).to eq([])
      end
    end
  end

  describe "#missing_decidim_users" do
    it "handles participants relation and returns ActiveRecord relation" do
      participants = Decidim::ActionDelegator::Participant.none
      result = helper.missing_decidim_users(participants)

      expect(result).to be_an(ActiveRecord::Relation)
    end
  end

  describe "#missing_registered_users" do
    it "handles participants relation and returns ActiveRecord relation" do
      participants = Decidim::ActionDelegator::Participant.none
      result = helper.missing_registered_users(participants)

      expect(result).to be_an(ActiveRecord::Relation)
    end
  end

  describe "#participants_uniq_ids" do
    let(:participants_with_phones) { [participant1, participant2] }

    before do
      allow(Decidim::ActionDelegator::Participant).to receive(:phone_combinations).and_return(%w(+34666666666 +34777777777))
      allow(Decidim::ActionDelegator::Participant).to receive(:verifier_ids).and_return(%w(id1 id2))
    end

    it "generates unique ids for participants based on phone combinations" do
      result = helper.participants_uniq_ids(participants_with_phones)

      expect(result).to eq(%w(id1 id2))
      expect(Decidim::ActionDelegator::Participant).to have_received(:phone_combinations).at_least(:once)
      expect(Decidim::ActionDelegator::Participant).to have_received(:verifier_ids).once
    end
  end

  describe "#existing_authorizations" do
    let(:participants) { [participant1, participant2] }

    before do
      allow(helper).to receive(:participants_uniq_ids).and_return(%w(uniq1 uniq2))
      allow(helper).to receive(:existing_authorizations).and_call_original
      allow(helper).to receive(:existing_authorizations).with(participants).and_return(Decidim::Authorization.none)
    end

    it "calls participants_uniq_ids" do
      result = helper.existing_authorizations(participants)

      expect(result).to respond_to(:count)
    end
  end

  describe "#total_missing_authorizations" do
    let(:participants) { [participant1, participant2] }

    before do
      allow(helper).to receive(:existing_authorizations).and_return(double(count: 1))
    end

    it "calculates total missing authorizations" do
      result = helper.total_missing_authorizations(participants)

      expect(result).to eq(1) # 2 participants - 1 existing authorization
      expect(helper).to have_received(:existing_authorizations).with(participants)
    end
  end
end
