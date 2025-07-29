# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Admin::ConsultationsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:consultation) { create(:consultation, organization: organization) }
      let(:user) { create(:user, :admin, :confirmed, organization: organization) }
      let(:setting) { create(:setting, consultation: consultation) }
      let!(:delegation) { create(:delegation, setting: setting, granter: user, grantee: grantee) }
      let(:grantee) { create(:user, :confirmed, organization: organization) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#results" do
        let(:question) { create(:question, consultation: consultation) }
        let(:question_response) { create(:response, question: question, title: { "ca" => "A" }) }

        before do
          question.votes.create(author: user, response: question_response)
        end

        it "renders decidim/admin/consultation layout" do
          get :results, params: { slug: consultation.slug }
          expect(response).to render_template("layouts/decidim/admin/consultation")
        end

        context "when the consultation is not finished" do
          let(:consultation) { create(:consultation, :unpublished, organization: organization) }

          it "does not load any response" do
            get :results, params: { slug: consultation.slug }
            expect(controller.helpers.responses_by_membership).not_to be_empty
            expect(controller.helpers.responses_by_weight).not_to be_empty
            expect(controller.helpers.total_delegates).to eq(1)
            expect(controller.helpers.questions).not_to be_empty
          end
        end

        context "when the consultation is finished" do
          let(:consultation) { create(:consultation, :finished, organization: organization) }

          it "loads the responses" do
            get :results, params: { slug: consultation.slug }
            expect(controller.helpers.responses_by_membership).not_to be_empty
            expect(controller.helpers.responses_by_weight).not_to be_empty
            expect(controller.helpers.total_delegates).to eq(1)
            expect(controller.helpers.questions).not_to be_empty
          end
        end
      end

      describe "#weighted_results" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:read, :consultation, anything)
          get :weighted_results, params: { slug: consultation.slug }
        end

        it "renders decidim/admin/consultation layout" do
          get :weighted_results, params: { slug: consultation.slug }
          expect(response).to render_template("layouts/decidim/admin/consultation")
        end
      end
    end
  end
end
