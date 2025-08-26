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
    end
  end
end
