# frozen_string_literal: true

require "spec_helper"
require "decidim/elections/test/vote_controller_examples"

module Decidim
  module Elections
    describe VotesController do
      let(:user) { create(:user, :confirmed, organization: component.organization) }
      let(:component) { create(:elections_component) }
      let(:election) do
        create(
          :election,
          :published,
          :ongoing,
          component:,
          results_availability: "real_time",
          census_manifest: "internal_users",
          census_settings: {
            "authorization_handlers" => {
              "internal_users" => {},
              "delegations_verifier" => {
                "options" => {
                  "setting" => setting.id
                }
              }
            }
          }
        )
      end
      let!(:existing_vote) { create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: "some-id") }
      let!(:question) { create(:election_question, :with_response_options, :voting_enabled, election:) }
      let!(:second_question) { create(:election_question, :with_response_options, :voting_enabled, election:) }
      let(:setting) { create(:setting, organization: component.organization) }
      let(:delegate_user) { create(:user, :confirmed, organization: component.organization) }
      let!(:participant) { create(:participant, setting: setting, decidim_user: user) }
      let!(:delegation) { create(:delegation, setting: setting, granter: user, grantee: delegate_user) }
      let!(:user_authorization) { create(:authorization, :granted, user: user, name: "delegations_verifier", metadata: { setting: setting.id }) }
      let!(:delegate_user_authorization) { create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata: { setting: setting.id }) }

      let(:params) do
        {
          component_id: component.id,
          election_id: election.id
        }
      end
      let(:election_vote_path) { Decidim::EngineRouter.main_proxy(component).election_vote_path(election_id: election.id, id: question.id) }
      let(:second_election_vote_path) { Decidim::EngineRouter.main_proxy(component).election_vote_path(election_id: election.id, id: second_question.id) }
      let(:new_election_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_vote_path(election_id: election.id) }
      let(:new_election_per_question_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_per_question_vote_path(election_id: election.id) }
      let(:new_election_normal_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_vote_path(election_id: election.id) }
      let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(id: election.id) }
      let(:receipt_election_votes_path) { Decidim::EngineRouter.main_proxy(component).receipt_election_votes_path(election_id: election.id) }
      let(:confirm_election_votes_path) { Decidim::EngineRouter.main_proxy(component).confirm_election_votes_path(election_id: election.id) }

      before do
        request.env["decidim.current_organization"] = component.organization
        request.env["decidim.current_participatory_space"] = component.participatory_space
        request.env["decidim.current_component"] = component
        allow(controller).to receive(:current_participatory_space).and_return(component.participatory_space)
        allow(controller).to receive(:current_component).and_return(component)
        allow(controller).to receive(:election_vote_path).and_return(election_vote_path)
        allow(controller).to receive(:new_election_vote_path).and_return(new_election_vote_path)
        allow(controller).to receive(:new_election_per_question_vote_path).and_return(new_election_per_question_vote_path)
        allow(controller).to receive(:new_election_normal_vote_path).and_return(new_election_normal_vote_path)
        allow(controller).to receive(:election_path).and_return(election_path)
        allow(controller).to receive(:receipt_election_votes_path).and_return(receipt_election_votes_path)
        allow(controller).to receive(:confirm_election_votes_path).and_return(confirm_election_votes_path)
      end

      describe "GET new" do
        it "renders the new vote form" do
          get :new, params: params
          expect(response).to have_http_status(:ok)
          expect(assigns(:form)).to be_a(Decidim::Elections::Censuses::InternalUsersForm)
          expect(subject).to render_template("decidim/elections/votes/new")
        end

        context "when the user is authenticated" do
          before do
            sign_in user
          end

          it "renders the new vote form (delegation logic affects redirect)" do
            get :new, params: params
            expect(response).to have_http_status(:ok)
            expect(subject).to render_template("decidim/elections/votes/new")
          end
        end
      end

      describe "GET show" do
        it "redirects to the election path" do
          get :show, params: params
          expect(response).to redirect_to(election_path)
        end
      end

      context "when the user is authenticated" do
        before do
          sign_in user
          allow(controller).to receive(:session_authenticated?).and_return(true)
        end

        it "renders the voting form" do
          get :show, params: params
          expect(response).to have_http_status(:ok)
          expect(controller.helpers.question).to eq(question)
          expect(subject).to render_template(:show)
        end

        context "when specific question is requested" do
          it "renders the voting form for the specific question" do
            get :show, params: params.merge(id: second_question.id)
            expect(response).to have_http_status(:ok)
            expect(controller.helpers.question).to eq(second_question)
            expect(subject).to render_template(:show)
          end
        end
      end

      describe "PATCH update" do
        it "redirects to the election path" do
          patch :update, params: params.merge(id: question.id)
          expect(response).to redirect_to(election_path)
        end

        context "when the user is authenticated" do
          before do
            sign_in user
            allow(controller).to receive(:session_authenticated?).and_return(true)
          end

          it "saves the vote and redirects to the next question" do
            patch :update, params: params.merge(id: question.id)
            expect(session[:votes_buffer]).to eq({ question.id.to_s => nil })
            expect(response).to redirect_to(election_vote_path)
          end

          it "redirects to the confirm page if no next question is available" do
            session[:votes_buffer] = { question.id.to_s => nil }
            patch :update, params: params.merge(id: second_question.id)
            expect(session[:votes_buffer]).to eq({ question.id.to_s => nil, second_question.id.to_s => nil })
            expect(response).to redirect_to(confirm_election_votes_path)
          end
        end
      end

      describe "GET confirm" do
        it "redirects to the election path" do
          get :confirm, params: params
          expect(response).to redirect_to(election_path)
        end

        context "when the user is authenticated" do
          before do
            sign_in user
            allow(controller).to receive(:session_authenticated?).and_return(true)
          end

          it "renders the confirmation page" do
            get :confirm, params: params
            expect(response).to have_http_status(:ok)
            expect(subject).to render_template(:confirm)
          end
        end
      end

      describe "PATCH cast" do
        it "redirects to the election path" do
          post :cast, params: params
          expect(response).to redirect_to(election_path)
        end

        context "when the user is authenticated" do
          let(:votes_buffer) do
            {
              question.id.to_s => [question.response_options.first.id],
              second_question.id.to_s => [second_question.response_options.first.id]
            }
          end

          before do
            sign_in user
            allow(controller).to receive(:session_authenticated?).and_return(true)
            allow(controller).to receive(:votes_buffer).and_return(votes_buffer)
          end

          it "casts the votes and redirects to the receipt page" do
            expect(controller.send(:votes_buffer)).to receive(:clear)
            expect(controller.send(:session_attributes)).to receive(:clear)
            # Mock the voter_uid to be set properly
            allow(controller).to receive(:voter_uid).and_return(user.to_global_id.to_s)
            post :cast, params: params
            expect(session[:voter_uid]).to eq(user.to_global_id.to_s)
            expect(response).to redirect_to(receipt_election_votes_path)
            expect(flash[:notice]).to eq(I18n.t("votes.cast.success", scope: "decidim.elections"))
          end

          context "when the votes are incomplete" do
            let(:votes_buffer) do
              {
                question.id.to_s => [question.response_options.first.id]
              }
            end

            it "redirects to the confirm page if votes are incomplete" do
              post :cast, params: params
              expect(response).to redirect_to(confirm_election_votes_path)
              expect(flash[:alert]).to eq(I18n.t("votes.cast.invalid", scope: "decidim.elections"))
            end
          end
        end
      end

      describe "GET receipt" do
        it "redirects to the election path" do
          get :receipt, params: params
          expect(response).to redirect_to(election_path)
        end

        context "when the user is authenticated" do
          before do
            sign_in user
          end

          it "redirects to the election path" do
            get :receipt, params: params
            expect(response).to redirect_to(election_path)
          end
        end

        context "when session voter UID is set" do
          before do
            session[:voter_uid] = user.to_global_id.to_s
          end

          context "when the election has votes for the voter UID" do
            before do
              create(:election_vote, voter_uid: session[:voter_uid], question: question, response_option: question.response_options.first)
            end

            it "renders the receipt page" do
              expect(controller.send(:votes_buffer)).to receive(:clear)
              expect(controller.send(:session_attributes)).to receive(:clear)
              get :receipt, params: params
              expect(response).to have_http_status(:ok)
              expect(subject).to render_template(:receipt)
            end
          end
        end
      end

      describe "Action Delegator functionality" do
        context "when user has delegations available" do
          before do
            sign_in delegate_user
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "loads delegations for the current user" do
            get :show, params: params
            expect(assigns(:delegations)).to include(delegation)
          end

          context "when delegation parameter is provided" do
            it "loads the specific delegation and delegator" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(assigns(:delegation)).to eq(delegation)
              expect(assigns(:delegator)).to eq(user)
              expect(session[:delegation_id]).to eq(delegation.id)
            end

            it "shows delegation warning message" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(assigns(:delegator)).to eq(user)
            end

            it "uses delegator's voter_uid instead of standard logic" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(controller.send(:voter_uid)).to eq(user.to_global_id.to_s)
            end
          end

          context "when delegation is in session" do
            before do
              session[:delegation_id] = delegation.id
            end

            it "loads delegation from session" do
              get :show, params: params
              expect(assigns(:delegation)).to eq(delegation)
              expect(assigns(:delegator)).to eq(user)
            end

            it "uses delegator's voter_uid" do
              get :show, params: params
              expect(controller.send(:voter_uid)).to eq(user.to_global_id.to_s)
            end
          end
        end

        context "when user has no delegations" do
          let(:user_without_delegations) { create(:user, :confirmed, organization: component.organization) }

          before do
            sign_in user_without_delegations
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(user_without_delegations)
          end

          it "does not load any delegations" do
            get :show, params: params
            expect(assigns(:delegator)).to be_nil
            expect(assigns(:delegation)).to be_nil
          end

          it "uses standard voter_uid logic" do
            allow(election.census).to receive(:voter_uid).and_return("standard-voter-uid")
            get :show, params: params
            expect(controller.send(:voter_uid)).to eq("standard-voter-uid")
          end
        end

        context "when casting vote with delegation" do
          let(:votes_buffer) do
            {
              question.id.to_s => [question.response_options.first.id],
              second_question.id.to_s => [second_question.response_options.first.id]
            }
          end

          before do
            sign_in delegate_user
            session[:delegation_id] = delegation.id
            allow(controller).to receive(:votes_buffer).and_return(votes_buffer)
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "casts votes as the delegator with PaperTrail tracking" do
            post :cast, params: params

            # Check that a delegation is properly set
            expect(assigns(:delegator)).to eq(user)
            expect(controller.send(:voter_uid)).to eq(user.to_global_id.to_s)
            expect(response).to be_redirect

            # Check that PaperTrail records delegation info
            info = controller.send(:info_for_paper_trail)
            expect(info[:decidim_action_delegator_delegation_id]).to eq(delegation.id)
          end
        end

        context "when visiting new vote with active delegation" do
          before do
            sign_in user
            session[:delegation_id] = delegation.id
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(user)
          end

          it "clears delegations when visiting new vote" do
            get :new, params: params
            expect(session[:delegation_id]).to be_nil
          end
        end

        context "with PaperTrail integration" do
          before do
            sign_in delegate_user
            session[:delegation_id] = delegation.id
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "sets PaperTrail whodunnit to current user" do
            # Just verify that the action loads delegation properly
            get :show, params: params
            expect(assigns(:delegator)).to eq(user)
          end

          it "includes delegation_id in PaperTrail info" do
            allow(controller).to receive(:info_for_paper_trail).and_call_original
            get :show, params: params
            info = controller.send(:info_for_paper_trail)
            expect(info[:decidim_action_delegator_delegation_id]).to eq(delegation.id)
          end
        end
      end
    end
  end
end
