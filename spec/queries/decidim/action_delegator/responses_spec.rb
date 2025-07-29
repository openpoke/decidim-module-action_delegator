# frozen_string_literal: true

require "spec_helper"

module Decidim::ActionDelegator
  describe Responses do
    subject { described_class.new(consultation) }

    let(:organization) { create(:organization) }

    let!(:question) { create(:question, consultation: consultation) }
    let!(:response) { create(:response, question: question, title: { "en" => "A" }) }

    let!(:other_consultation) { create(:consultation, :finished, :published_results, organization: organization) }
    let!(:other_question) { create(:question, consultation: other_consultation) }
    let!(:other_response) { create(:response, question: other_question, title: { "en" => "other" }) }

    describe "#query" do
      context "when the consultation is active" do
        let(:consultation) { create(:consultation, :active, organization: organization) }

        it "returns present" do
          expect(subject.query).not_to be_empty
        end
      end

      context "when the consultation is not published but ended" do
        let(:consultation) do
          create(:consultation, :unpublished, end_voting_date: 1.day.ago, organization: organization)
        end

        it "returns empty" do
          expect(subject.query).not_to be_empty
        end
      end

      context "when the consultation is published but not ended" do
        let(:consultation) do
          create(:consultation, :published, end_voting_date: 1.day.from_now, organization: organization)
        end

        it "returns empty" do
          expect(subject.query).not_to be_empty
        end
      end

      context "when the consultation is published and ended" do
        let(:consultation) { create(:consultation, :finished, organization: organization) }

        context "and the questions are published" do
          let!(:question) { create(:question, :published, consultation: consultation) }

          it "returns the responses to its questions" do
            expect(subject.query).to contain_exactly(response)
          end
        end

        context "and the questions are not published" do
          let!(:question) { create(:question, :unpublished, consultation: consultation) }

          it "returns empty" do
            expect(subject.query).to be_empty
          end
        end
      end
    end
  end
end
