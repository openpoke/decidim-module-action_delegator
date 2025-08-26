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

      # context "when users are from a different organization than the consultation" do
      #   let(:consultation) { create(:consultation) }
      #   let(:setting) { create(:setting, consultation: consultation) }
      #   let(:grantee) { create(:user) }
      #   let(:granter) { create(:user, organization: grantee.organization) }

      #   subject { build(:delegation, grantee: grantee, granter: granter, setting: setting) }

      #   it { is_expected.not_to be_valid }
      # end

      # describe ".granted_to?" do
      #   subject { delegation }

      #   let!(:delegation) { create(:delegation, setting: setting) }
      #   let(:user) { create(:user) }
      #   let(:consultation) { create(:consultation, :active, organization: user.organization) }
      #   let(:question) { create(:question, consultation: consultation) }
      #   let(:response) { create(:response, question: question) }
      #   let!(:vote) { create(:vote, question: question, response: response, author: user) }
      #   let(:setting) { create(:setting, consultation: consultation) }

      #   shared_examples "can be destroyed" do
      #     it { is_expected.not_to be_grantee_voted }

      #     it "can be destroyed" do
      #       expect { subject.destroy }.to change(described_class, :count).by(-1)
      #     end
      #   end

      #   shared_examples "cannot be destroyed" do
      #     it { is_expected.to be_grantee_voted }

      #     it "cannot be destroyed" do
      #       expect { subject.destroy }.not_to change(described_class, :count)
      #     end
      #   end

      #   it_behaves_like "can be destroyed"

      #   context "when there is no delegation granted to user for the given consultation" do
      #     it "returns false" do
      #       expect(described_class.granted_to?(user, consultation)).to be(false)
      #     end

      #     it_behaves_like "can be destroyed"
      #   end

        # context "when there are delegations granted to user for the given consultation" do
        #   let!(:delegation) { create(:delegation, setting: setting, grantee: user) }

        #   it "returns true" do
        #     expect(described_class.granted_to?(user, consultation)).to be(true)
        #   end

        #   it_behaves_like "can be destroyed"

        #   context "and granter has voted", versioning: true do
        #     let!(:vote) { create(:vote, question: question, response: response, author: delegation.granter) }

        #     it_behaves_like "can be destroyed"

        #     context "and grantee has voted in behalf of the granter" do
        #       before do
        #         PaperTrail::Version.create!(
        #           item_type: "Decidim::Consultations::Vote",
        #           item_id: vote.id,
        #           event: "create",
        #           whodunnit: delegation.grantee.id,
        #           decidim_action_delegator_delegation_id: delegation.id
        #         )
        #       end

        #       it_behaves_like "cannot be destroyed"
        #     end
        #   end
        # end
      end
    end
  end
end
