# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Consultations
    describe VoteQuestion do
      subject { described_class.new(form) }

      let(:organization) { create(:organization) }
      let(:consultation) { create(:consultation, organization: organization) }
      let(:question) { create(:question, consultation: consultation) }
      let(:user) { create(:user, organization: organization) }
      let(:response) { create(:response, question: question) }
      let(:decidim_consultations_response_id) { response.id }
      let(:attributes) do
        {
          decidim_consultations_response_id: decidim_consultations_response_id
        }
      end

      let(:form) do
        VoteForm
          .from_params(attributes)
          .with_context(current_user: user, current_question: question)
      end

      before do
        allow(subject).to receive(:session).and_return({})
      end

      context "when user votes the question" do
        it "broadcasts ok" do
          expect { subject.call }.to broadcast :ok
        end

        it "creates a vote" do
          expect do
            subject.call
          end.to change(Vote, :count).by(1)
        end

        it "increases the votes counter by one" do
          expect do
            subject.call
            question.reload
          end.to change(question, :votes_count).by(1)
        end

        it "increases the response counter by one" do
          expect do
            subject.call
            response.reload
          end.to change(response, :votes_count).by(1)
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
              decidim_consultations_response_id: decidim_consultations_response_id,
              decidim_consultations_delegation_id: delegation.id
            }
          end

          let(:form) do
            VoteForm
              .from_params(attributes)
              .with_context(current_user: user, current_question: question)
          end

          before do
            allow(subject).to receive(:session).and_return({ delegation_id: delegation.id })
          end

          it "creates a vote with the granter as author" do
            expect do
              subject.call
            end.to change(Vote.where(author: delegation.granter), :count).by(1)
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
        let!(:vote) { create(:vote, author: user, question: question) }

        it "broadcasts invalid" do
          expect { subject.call }.to broadcast(:invalid)
        end
      end
    end
  end
end
