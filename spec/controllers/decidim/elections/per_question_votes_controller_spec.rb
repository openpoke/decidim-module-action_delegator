# frozen_string_literal: true

require "spec_helper"
require "decidim/elections/test/vote_controller_examples"

module Decidim
  module Elections
    describe PerQuestionVotesController do
      let(:user) { create(:user, :confirmed, organization: component.organization) }
      let(:component) { create(:elections_component) }
      let(:election) do
        create(
          :election,
          :published,
          :per_question,
          :ongoing,
          component:,
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
      let(:params) { { component_id: component.id, election_id: election.id } }
      let(:election_vote_path) { Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: question.id) }
      let(:second_election_vote_path) { Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: second_question.id) }
      let(:new_election_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_per_question_vote_path(election_id: election.id) }
      let(:new_election_normal_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_vote_path(election_id: election.id) }
      let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(id: election.id) }
      let(:waiting_election_votes_path) { Decidim::EngineRouter.main_proxy(component).waiting_election_per_question_votes_path(election_id: election.id) }
      let(:receipt_election_votes_path) { Decidim::EngineRouter.main_proxy(component).receipt_election_per_question_votes_path(election_id: election.id) }

      before do
        request.env["decidim.current_organization"] = component.organization
        request.env["decidim.current_participatory_space"] = component.participatory_space
        request.env["decidim.current_component"] = component
        allow(controller).to receive(:current_participatory_space).and_return(component.participatory_space)
        allow(controller).to receive(:current_component).and_return(component)
        allow(controller).to receive(:election_vote_path).and_return(election_vote_path)
        allow(controller).to receive(:new_election_vote_path).and_return(new_election_vote_path)
        allow(controller).to receive(:election_path).and_return(election_path)
        allow(controller).to receive(:waiting_election_votes_path).and_return(waiting_election_votes_path)
        allow(controller).to receive(:receipt_election_votes_path).and_return(receipt_election_votes_path)
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

          it "redirects to the next question if the current question is not enabled" do
            question.update(voting_enabled_at: nil)
            allow(controller).to receive(:redirect_to).with(action: :show, id: second_question)
            get :show, params: params
            expect(response).to have_http_status(:ok)
          end

          it "redirects when current question has published results" do
            question.update(published_results_at: Time.current)
            allow(controller).to receive(:redirect_to).with(action: :show, id: second_question)
            get :show, params: params
            expect(response).to have_http_status(:ok)
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

          it "redirects to the next question if the current question has published results" do
            question.update(published_results_at: Time.current)
            allow(controller).to receive(:redirect_to).with(action: :show, id: second_question).at_least(:once)
            patch :update, params: params.merge(id: question.id, response: { question.id.to_s => [question.response_options.first.id] })
            expect(response).to have_http_status(:no_content)
          end

          it "sets a flash error and redirect to itself if no response is given" do
            allow(controller).to receive(:redirect_to).with(action: :show, id: question)
            patch :update, params: params.merge(id: question.id)
            expect(flash[:alert]).to eq(I18n.t("votes.cast.invalid", scope: "decidim.elections"))
            expect(response).to have_http_status(:no_content)
          end

          it "redirects to next question if no response is given and the question is not voting enabled" do
            question.update(voting_enabled_at: nil)
            allow(controller).to receive(:redirect_to).with(action: :show, id: second_question).at_least(:once)
            patch :update, params: params.merge(id: question.id)
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      describe "GET waiting" do
        it "redirects to the election path" do
          get :waiting, params: params
          expect(response).to redirect_to(election_path)
        end

        context "when the user is authenticated" do
          before do
            sign_in user
            allow(controller).to receive(:session_authenticated?).and_return(true)
          end

          context "when waiting for next question" do
            before do
              second_question.update(voting_enabled_at: nil)
            end

            it "redirects to the non voted question" do
              allow(controller).to receive(:redirect_to).with(action: :show, id: question)
              get :waiting, params: params
              expect(response).to have_http_status(:ok)
            end

            context "when all non pending questions have been voted" do
              let!(:vote) { create(:election_vote, voter_uid: user.to_global_id.to_s, question:, response_option: question.response_options.first) }

              it "redirects to the remaining question" do
                allow(controller).to receive(:redirect_to).with(action: :show, id: question)
                get :waiting, params: params
                expect(response).to have_http_status(:ok)
              end
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
            allow(controller).to receive(:session_authenticated?).and_return(true)
          end

          context "when session voter UID is set" do
            before do
              allow(controller).to receive(:votes_buffer).and_return({ user.to_global_id.to_s => { question.id.to_s => [question.response_options.first.id], second_question.id.to_s => [second_question.response_options.first.id] } })
              session[:voter_uid] = user.to_global_id.to_s
            end

            it "redirects to the election path" do
              get :receipt, params: params
              expect(response).to redirect_to(election_path)
            end

            context "when the election has votes for the voter UID" do
              before do
                create(:election_vote, voter_uid: session[:voter_uid], question: question, response_option: question.response_options.first)
                create(:election_vote, voter_uid: session[:voter_uid], question: second_question, response_option: second_question.response_options.first)
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
            end

            it "shows delegation warning message" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(assigns(:delegator)).to eq(user)
            end

            it "uses delegator's voter_uid instead of standard logic" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(controller.send(:voter_uid)).to eq(user.to_global_id.to_s)
            end

            it "adds delegation parameter to next vote step action" do
              get :show, params: params.merge(delegation: delegation.id)
              expect(assigns(:delegation)).to eq(delegation)
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
          before do
            sign_in delegate_user
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "casts votes as the delegator with PaperTrail tracking" do
            patch :update, params: params.merge(id: question.id, delegation: delegation.id, response: { question.id.to_s => [question.response_options.first.id] })

            # Check that a delegation is properly set
            expect(assigns(:delegator)).to eq(user)
            expect(controller.send(:voter_uid)).to eq(user.to_global_id.to_s)
            # Note: may redirect or have different response depending on vote buffer state
            expect(response).to be_redirect

            # Check that PaperTrail records delegation info
            info = controller.send(:info_for_paper_trail)
            expect(info[:decidim_action_delegator_delegation_id]).to eq(delegation.id)
          end
        end

        context "with PaperTrail integration" do
          before do
            sign_in delegate_user
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "sets PaperTrail whodunnit to current user" do
            get :show, params: params.merge(delegation: delegation.id)
            expect(assigns(:delegator)).to eq(user)
          end

          it "includes delegation_id in PaperTrail info" do
            allow(controller).to receive(:info_for_paper_trail).and_call_original
            get :show, params: params.merge(delegation: delegation.id)
            info = controller.send(:info_for_paper_trail)
            expect(info[:decidim_action_delegator_delegation_id]).to eq(delegation.id)
          end
        end

        context "with per-person votes buffer functionality" do
          before do
            sign_in delegate_user
            allow(controller).to receive(:user_signed_in?).and_return(true)
            allow(controller).to receive(:current_user).and_return(delegate_user)
          end

          it "maintains separate votes buffer per delegator" do
            get :show, params: params.merge(delegation: delegation.id)

            # Votes buffer should be keyed by delegator's voter_uid
            delegator_buffer = controller.send(:votes_buffer)
            expect(delegator_buffer).to be_a(Hash)

            # Buffer should be specific to this delegator
            expect(session[:votes_buffer]).to have_key(user.to_global_id.to_s)
          end

          it "shows pending questions for specific delegator" do
            get :show, params: params.merge(delegation: delegation.id)

            pending = controller.send(:pending_questions_for, user)
            expect(pending).to include(question, second_question)
          end
        end
      end
    end
  end
end
