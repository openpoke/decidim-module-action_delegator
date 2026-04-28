# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Delegation do
      subject { build(:delegation) }

      it { is_expected.to belong_to(:setting) }
      it { is_expected.to be_valid }
      it { is_expected.not_to be_grantee_voted }

      context "when grantee is the same as the granter" do
        let(:setting) { create(:setting) }
        let(:grantee) { create(:user, organization: setting.organization) }

        subject { build(:delegation, setting: setting, grantee: grantee, granter: grantee) }

        it { is_expected.not_to be_valid }
      end

      context "when users from different organizations" do
        let(:grantee) { create(:user) }

        subject { build(:delegation, grantee: grantee) }

        it { is_expected.not_to be_valid }
      end

      context "when users are from a different organization than the setting" do
        let(:setting) { create(:setting) }
        let(:grantee) { create(:user) }
        let(:granter) { create(:user, organization: grantee.organization) }

        subject { build(:delegation, grantee: grantee, granter: granter, setting: setting) }

        it { is_expected.not_to be_valid }
      end

      context "when granter already has a delegation in the same setting" do
        let(:setting) { create(:setting) }
        let(:granter) { create(:user, organization: setting.organization) }
        let!(:existing_delegation) { create(:delegation, setting: setting, granter: granter) }

        subject { build(:delegation, setting: setting, granter: granter) }

        it { is_expected.not_to be_valid }
      end

      describe "#grantee_voted?", versioning: true do
        let(:setting) { create(:setting) }
        let(:granter) { create(:user, organization: setting.organization) }
        let(:grantee) { create(:user, organization: setting.organization) }
        let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: grantee) }
        let(:election) { create(:election, :ongoing, skip_injection: true) }
        let(:question) { create(:election_question, :with_response_options, skip_injection: true, election: election) }
        let!(:vote) { create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: granter.to_global_id.to_s) }

        context "when grantee has not voted on behalf of granter" do
          it "returns false" do
            expect(delegation.grantee_voted?).to be(false)
          end
        end

        context "when grantee has voted on behalf of granter" do
          before do
            PaperTrail::Version.create!(
              item_type: "Decidim::Elections::Vote",
              item_id: vote.id,
              event: "create",
              whodunnit: grantee.id.to_s,
              object_changes: { decidim_action_delegator_delegation_id: delegation.id }
            )
          end

          it "returns true" do
            expect(delegation.grantee_voted?).to be(true)
          end

          it "blocks destroy" do
            expect { delegation.destroy }.not_to change(described_class, :count)
          end
        end
      end
    end
  end
end
