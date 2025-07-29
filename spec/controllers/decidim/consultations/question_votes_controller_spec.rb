# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Consultations
    describe QuestionVotesController do
      routes { Decidim::Consultations::Engine.routes }

      let(:organization) { create(:organization) }
      let(:user) { create(:user, :confirmed, organization: organization) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#destroy" do
        let(:consultation) { create(:consultation, organization: organization) }
        let(:question) { create(:question, consultation: consultation) }
        let(:setting) { create(:setting, consultation: consultation) }

        context "when a delegation is specified", versioning: true do
          let(:delegation) { create(:delegation, setting: setting, grantee: user) }
          let!(:vote) { create(:vote, author: delegation.granter, question: question) }

          it "destroys the vote" do
            delete :destroy, params: { question_slug: question.slug, decidim_consultations_delegation_id: delegation.id }, format: :js
            expect(response).to render_template(:update_vote_button)
          end

          it "creates a new version" do
            expect do
              delete :destroy, params: { question_slug: question.slug, decidim_consultations_delegation_id: delegation.id }, format: :js
            end.to change(PaperTrail::Version, :count)
          end

          it "tracks who performed the unvote" do
            delete :destroy, params: { question_slug: question.slug, decidim_consultations_delegation_id: delegation.id }, format: :js
            version = vote.versions.last
            expect(version.whodunnit).to eq(user.id.to_s)
          end

          it "tracks the delegation the unvote is related to" do
            delete :destroy, params: { question_slug: question.slug, decidim_consultations_delegation_id: delegation.id }, format: :js
            version = vote.versions.last
            expect(version.decidim_action_delegator_delegation_id).to eq(delegation.id)
          end
        end

        context "when no delegation is specified", versioning: true do
          before { create(:vote, author: user, question: question) }

          it "destroys the vote" do
            delete :destroy, params: { question_slug: question.slug }, format: :js
            expect(response).to render_template(:update_vote_button)
          end

          it "does not create a new version" do
            expect { delete :destroy, params: { question_slug: question.slug }, format: :js }
              .not_to change(PaperTrail::Version, :count)
          end
        end
      end
    end
  end
end
