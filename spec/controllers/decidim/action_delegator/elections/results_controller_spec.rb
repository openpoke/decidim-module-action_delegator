# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Elections
      describe ResultsController do
        routes { Decidim::ActionDelegator::Engine.routes }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, :confirmed, organization:) }
        let(:component) { create(:elections_component, organization:) }
        let(:setting) { create(:setting, organization:) }
        let(:election) do
          create(:election, :published, :ongoing, :with_questions,
                 component:,
                 census_manifest: "internal_users",
                 census_settings: {
                   "authorization_handlers" => {
                     "delegations_verifier" => {
                       "options" => {
                         "setting" => [setting.id]
                       }
                     }
                   }
                 })
        end
        let(:question) { election.questions.first }
        let(:response_option) { question.response_options.first }
        let(:ponderation) { create(:ponderation, setting:) }
        let(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

        before do
          request.env["decidim.current_organization"] = organization
        end

        describe "#sum_of_weights" do
          let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

          it "returns successful response" do
            get :sum_of_weights, params: { id: election.id }
            expect(response).to be_successful
          end

          it "returns JSON with election data" do
            get :sum_of_weights, params: { id: election.id }

            response_data = response.parsed_body

            expect(response_data["id"]).to eq(election.id)
            expect(response_data).to have_key("ongoing")
            expect(response_data["questions"]).to be_an(Array)
          end

          it "returns questions with weighted response options" do
            get :sum_of_weights, params: { id: election.id }

            response_data = response.parsed_body
            question_data = response_data["questions"].first

            expect(question_data["id"]).to eq(question.id)
            expect(question_data).to have_key("body")
            expect(question_data).to have_key("published_results")
            expect(question_data).to have_key("response_options")
            expect(question_data["response_options"]).to be_an(Array)
          end

          context "with published results" do
            let(:election) do
              create(:election, :published, :finished, :published_results, :with_questions,
                     component:,
                     census_manifest: "internal_users",
                     census_settings: {
                       "authorization_handlers" => {
                         "delegations_verifier" => {
                           "options" => {
                             "setting" => [setting.id]
                           }
                         }
                       }
                     })
            end

            before do
              question.update!(published_results_at: Time.current)
            end

            it "includes full response option data when results are published" do
              get :sum_of_weights, params: { id: election.id }

              response_data = response.parsed_body
              question_data = response_data["questions"].first
              option_data = question_data["response_options"].first

              expect(option_data).to have_key("id")
              expect(option_data).to have_key("question_id")
              expect(option_data).to have_key("body")
              expect(option_data).to have_key("votes_count")
              expect(option_data).to have_key("votes_percent")
            end
          end

          context "with unpublished results" do
            before do
              question.update!(published_results_at: nil)
            end

            it "returns limited response option data when results are not published" do
              get :sum_of_weights, params: { id: election.id }

              response_data = response.parsed_body
              question_data = response_data["questions"].first
              option_data = question_data["response_options"].first

              expect(option_data).to have_key("id")
              expect(option_data).to have_key("question_id")
              expect(option_data).to have_key("body")

              expect(option_data).not_to have_key("votes_count")
              expect(option_data).not_to have_key("votes_percent")
            end
          end

          context "with weighted votes" do
            let(:ponderation_with_weight) { create(:ponderation, setting:, weight: 5.0) }
            let(:participant_with_weight) { create(:participant, setting:, ponderation: ponderation_with_weight) }
            let(:weighted_user) { create(:user, :confirmed, organization:) }

            before do
              participant_with_weight.update!(decidim_user: weighted_user)
              create(:election_vote, question:, response_option:, voter_uid: weighted_user.to_global_id.to_s)
            end

            it "includes weighted responses in calculations" do
              get :sum_of_weights, params: { id: election.id }

              response_data = response.parsed_body
              question_data = response_data["questions"].first

              expect(question_data["response_options"]).not_to be_empty
            end
          end

          context "with multiple questions" do
            let(:question2) { create(:election_question, :with_response_options, election:) }
            let(:response_option2) { question2.response_options.first }
            let!(:vote2) { create(:election_vote, question: question2, response_option: response_option2, voter_uid: user.to_global_id.to_s) }

            it "returns all questions" do
              get :sum_of_weights, params: { id: election.id }

              response_data = response.parsed_body

              expect(response_data["questions"].length).to eq(3)
              question_ids = response_data["questions"].map { |q| q["id"] }
              expect(question_ids).to include(question.id, question2.id)
            end
          end
        end

        describe "election access" do
          context "when election is not published" do
            let(:unpublished_election) { create(:election, :with_questions, component:) }

            it "raises ActiveRecord::RecordNotFound for unpublished election" do
              expect do
                get :sum_of_weights, params: { id: unpublished_election.id }
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end

          context "when election does not exist" do
            it "raises ActiveRecord::RecordNotFound for non-existent election" do
              expect do
                get :sum_of_weights, params: { id: 99_999 }
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end

        describe "JSON format" do
          let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

          it "returns valid JSON" do
            get :sum_of_weights, params: { id: election.id }

            expect(response.content_type).to include("application/json")
            expect { response.parsed_body }.not_to raise_error
          end

          it "includes election status information" do
            get :sum_of_weights, params: { id: election.id }

            response_data = response.parsed_body

            expect(response_data["ongoing"]).to be_in([true, false])
            expect(response_data["id"]).to be_a(Integer)
          end
        end

        describe "question body translation" do
          let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

          it "includes translated question body" do
            get :sum_of_weights, params: { id: election.id }

            response_data = response.parsed_body
            question_data = response_data["questions"].first

            expect(question_data["body"]).to be_a(String)
            expect(question_data["body"]).not_to be_empty
          end
        end
      end
    end
  end
end
