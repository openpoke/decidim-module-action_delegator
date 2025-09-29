# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Elections
      module Admin
        describe ResultsController do
          routes { Decidim::ActionDelegator::Engine.routes }

          let(:organization) { create(:organization) }
          let(:user) { create(:user, :admin, :confirmed, organization:) }
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
            sign_in user
          end

          describe "#by_type_and_weight" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "returns successful response" do
              get :by_type_and_weight, params: { id: election.id }
              expect(response).to be_successful
            end

            it "returns JSON with election data" do
              get :by_type_and_weight, params: { id: election.id }

              response_data = response.parsed_body

              expect(response_data["id"]).to eq(election.id)
              expect(response_data).to have_key("ongoing")
              expect(response_data["questions"]).to be_an(Array)
            end

            it "returns questions with response options" do
              get :by_type_and_weight, params: { id: election.id }

              response_data = response.parsed_body
              question_data = response_data["questions"].first

              expect(question_data["id"]).to eq(question.id)
              expect(question_data).to have_key("response_options")
              expect(question_data["response_options"]).to be_an(Array)
            end

            context "with multiple questions and answers" do
              let(:question2) { create(:election_question, :with_response_options, election:) }
              let(:response_option2) { question2.response_options.first }
              let(:vote2) { create(:election_vote, question: question2, response_option: response_option2, voter_uid: user.to_global_id.to_s) }

              before do
                vote2
              end

              it "returns all questions" do
                get :by_type_and_weight, params: { id: election.id }

                response_data = response.parsed_body

                expect(response_data["questions"].length).to eq(3)
                question_ids = response_data["questions"].map { |q| q["id"] }
                expect(question_ids).to include(question.id, question2.id)
              end
            end
          end

          describe "#sum_of_weights" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "returns successful response" do
              get :sum_of_weights, params: { id: election.id }
              expect(response).to be_successful
            end

            it "returns JSON with election data and weighted responses" do
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
              expect(question_data).to have_key("response_options")
              expect(question_data["response_options"]).to be_an(Array)
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
          end

          describe "#totals" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "returns successful response" do
              get :totals, params: { id: election.id }
              expect(response).to be_successful
            end

            it "returns JSON with election totals data" do
              get :totals, params: { id: election.id }

              response_data = response.parsed_body

              expect(response_data["id"]).to eq(election.id)
              expect(response_data).to have_key("ongoing")
              expect(response_data["questions"]).to be_an(Array)
            end

            it "returns questions with statistics" do
              get :totals, params: { id: election.id }

              response_data = response.parsed_body
              question_data = response_data["questions"].first

              expect(question_data["id"]).to eq(question.id)
              expect(question_data).to have_key("participants")
              expect(question_data).to have_key("unweighted_votes")
              expect(question_data).to have_key("weighted_votes")
              expect(question_data).to have_key("delegated_votes")
            end

            context "with delegated votes" do
              let(:delegator_user) { create(:user, :confirmed, organization:) }
              let(:delegatee_user) { create(:user, :confirmed, organization:) }
              let(:delegation) { create(:delegation, setting:, granter: delegator_user, grantee: delegatee_user) }
              let(:delegated_vote) do
                create(:election_vote, question:, response_option:, voter_uid: delegatee_user.to_global_id.to_s).tap do |vote|
                  vote.versions.create!(
                    decidim_action_delegator_delegation_id: delegation.id,
                    item_type: vote.class.name,
                    item_id: vote.id,
                    event: "create"
                  )
                end
              end

              before do
                create(:participant, setting:, decidim_user: delegator_user)
                create(:participant, setting:, decidim_user: delegatee_user)
                delegation
                delegated_vote
              end

              it "includes delegated votes in statistics" do
                get :totals, params: { id: election.id }

                response_data = response.parsed_body
                question_data = response_data["questions"].first

                expect(question_data["delegated_votes"]).to be > 0
              end
            end

            context "with multiple participants" do
              let(:user2) { create(:user, :confirmed, organization:) }
              let(:participant2) { create(:participant, setting:, decidim_user: user2, ponderation:) }
              let(:vote2) { create(:election_vote, question:, response_option:, voter_uid: user2.to_global_id.to_s) }

              before do
                participant2
                vote2
              end

              it "counts multiple participants correctly" do
                get :totals, params: { id: election.id }

                response_data = response.parsed_body
                question_data = response_data["questions"].first

                expect(question_data["participants"]).to eq(2)
                expect(question_data["unweighted_votes"]).to eq(2)
              end
            end
          end

          describe "election not found" do
            it "raises ActiveRecord::RecordNotFound for non-existent election" do
              expect do
                get :by_type_and_weight, params: { id: 99_999 }
              end.to raise_error(ActiveRecord::RecordNotFound)
            end
          end
        end
      end
    end
  end
end
