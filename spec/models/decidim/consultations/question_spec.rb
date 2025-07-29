# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Consultations
    describe Question do
      subject { question }

      let(:consultation) { create(:consultation, :published, :active) }
      let(:question) { create(:question, consultation: consultation) }
      let(:responses) { create_list(:response, 3, question: question) }
      let!(:votes) do
        responses.map.with_index do |response, index|
          create_list(:vote, index + 1, question: question, response: response)
        end.flatten
      end

      it { is_expected.to be_publishable_results }

      context "when mod is not enabled" do
        before do
          allow(Decidim::ActionDelegator).to receive(:admin_preview_results).and_return(false)
        end

        it { is_expected.not_to be_publishable_results }
      end

      describe "#weighted_responses" do
        it "groups responses by question and calculates their weight" do
          expect(question.weighted_responses[question.id].map(&:votes_count)).to contain_exactly(1, 2, 3)
        end
      end

      describe "#total_weighted_votes" do
        it "returns the total weighted vote count for the question" do
          # The total number of votes = 1 + 2 + 3
          expect(question.total_weighted_votes).to eq(6)
        end
      end

      describe "#most_weighted_voted_response" do
        it "returns the response with the highest weighted vote count" do
          # The response with the highest vote count has 3 votes
          expect(question.most_weighted_voted_response.votes_count).to eq(3)
        end
      end

      describe "#responses_sorted_by_weighted_votes" do
        it "returns responses sorted by descending weighted vote count" do
          sorted_votes_counts = question.responses_sorted_by_weighted_votes[question.id].map(&:votes_count)
          expect(sorted_votes_counts).to eq([3, 2, 1])
        end
      end
    end
  end
end
