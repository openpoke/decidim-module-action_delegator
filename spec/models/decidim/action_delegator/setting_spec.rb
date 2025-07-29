# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Setting do
      subject { build(:setting, consultation: consultation, authorization_method: authorization_method) }

      let(:authorization_method) { :email }
      let(:consultation) { create(:consultation, start_voting_date: start_voting_date, end_voting_date: end_voting_date) }
      let(:start_voting_date) { 1.day.ago }
      let(:end_voting_date) { 1.day.from_now }

      it { is_expected.to belong_to(:consultation) }
      it { is_expected.to have_many(:delegations).dependent(:restrict_with_error) }
      it { is_expected.to have_many(:ponderations).dependent(:restrict_with_error) }
      it { is_expected.to have_many(:participants).dependent(:restrict_with_error) }
      it { is_expected.to validate_presence_of(:max_grants) }
      it { is_expected.to validate_numericality_of(:max_grants).is_greater_than(0) }

      it "returns the consultation title" do
        expect(subject.title).to eq(consultation.title)
      end

      it "returns the state" do
        expect(subject.state).to eq(:ongoing)
        expect(subject).to be_ongoing
        expect(subject).to be_editable
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

      context "when the consultation is finished" do
        let(:end_voting_date) { 1.day.ago }

        it "returns the state" do
          expect(subject.state).to eq(:closed)
          expect(subject).not_to be_ongoing
          expect(subject).not_to be_editable
        end
      end

      context "when the consultation is not yet started" do
        let(:start_voting_date) { 1.day.from_now }

        it "returns the state" do
          expect(subject.state).to eq(:pending)
          expect(subject).to be_editable
          expect(subject).not_to be_ongoing
        end
      end
    end
  end
end
