# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Consultations
    describe MultipleVoteQuestion do
      subject { described_class.new(form, user) }

      let(:organization) { create(:organization) }
      let(:consultation) { create(:consultation, organization: organization) }
      let(:question) { create(:question, :multiple, consultation: consultation) }
      let(:user) { create(:user, organization: organization) }
      let(:response1) { create(:response, question: question) }
      let(:response2) { create(:response, question: question) }
      let(:response3) { create(:response, question: question) }
      let(:responses) do
        [response1.id, response2.id]
      end
      let(:attributes) do
        {
          responses: responses
        }
      end

      let(:form) do
        MultiVoteForm
          .from_params(attributes)
          .with_context(current_user: user, current_question: question)
      end

      context "when user votes the question" do
        before do
          allow(subject).to receive(:session).and_return({})
        end

        it "broadcasts ok" do
          expect { subject.call }.to broadcast :ok
        end

        it "creates a vote" do
          expect do
            subject.call
          end.to change(Vote, :count).by(2)
        end

        it "increases the votes counter by two" do
          expect do
            subject.call
            question.reload
          end.to change(question, :votes_count).by(2)
        end

        it "increases the responsess counter by one" do
          subject.call
          expect(response1.reload.votes_count).to eq(1)
          expect(response2.reload.votes_count).to eq(1)
          expect(response3.reload.votes_count).to eq(0)
        end

        describe "originator", versioning: true do
          it "does not track who was responsible for the action" do
            expect { subject.call }
              .not_to change(PaperTrail::Version.where(item_type: "Decidim::Consultations::Vote"), :count)
          end
        end

        context "when there is a delegation available" do
          let(:setting) { create(:setting, consultation: consultation) }
          let(:granter) { create(:user, organization: organization) }
          let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: user) }
          let(:attributes) do
            {
              responses: responses,
              decidim_consultations_delegation_id: delegation.id
            }
          end

          let(:form) do
            MultiVoteForm
              .from_params(attributes)
              .with_context(current_user: user, current_question: question)
          end

          before do
            allow(subject).to receive(:session).and_return({ delegation_id: delegation.id })
          end

          it "creates a vote with the granter as author" do
            expect do
              subject.call
            end.to change(Vote.where(author: delegation.granter), :count).by(2)
          end

          describe "originator", versioning: true do
            it "tracks who was responsible for the action" do
              subject.call
              vote = Vote.last
              expect(vote.paper_trail.originator).to eq(delegation.grantee.id.to_s)
            end
          end
        end
      end

      context "when user tries to vote twice" do
        let!(:vote) { create(:vote, author: user, question: question, response: response1) }

        it "repeated voting do not increment number of responses" do
          expect(question.responses_count).to eq(1)
          subject.call
          expect(question.responses_count).to eq(2)
        end
      end
    end
  end
end
