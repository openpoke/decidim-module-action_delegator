# frozen_string_literal: true

require "spec_helper"

shared_examples "weighted results navigation" do
  it "displays weighted results navigation tabs" do
    expect(page).to have_content("By answer")
    expect(page).to have_content("By type and weight")
    expect(page).to have_content("Sum of weights")
    expect(page).to have_content("Totals")
  end

  it "shows results type info callout" do
    expect(page).to have_css(".callout.callout-info")
    expect(page).to have_content("How to interpret these results?")
  end
end

shared_examples "live update functionality" do
  it "includes live update functionality" do
    expect(page.html).to include("data-weight-results-live-update")
  end
end

describe "Admin weighted results in elections" do
  include_context "when managing a component as an admin"

  let(:manifest_name) { "elections" }
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:setting) { create(:setting, organization:) }
  let!(:election) do
    create(
      :election,
      :published,
      :ongoing,
      :with_questions,
      component:,
      census_manifest: "internal_users",
      census_settings: {
        "authorization_handlers" => {
          "delegations_verifier" => {
            "options" => {
              "setting" => setting.id.to_s
            }
          }
        }
      }
    )
  end
  let(:question) { election.questions.first }
  let(:response_option_first) { question.response_options.first }
  let(:response_option_second) { question.response_options.second }
  # Create ponderations with different weights
  let!(:ponderation_low) { create(:ponderation, setting:, name: "Basic Weight", weight: 1.0) }
  let!(:ponderation_high) { create(:ponderation, setting:, name: "High Weight", weight: 3.0) }
  # Create users with different participation types
  let!(:basic_user_first) { create(:user, :confirmed, organization:) }
  let!(:basic_user_second) { create(:user, :confirmed, organization:) }
  let!(:high_user_first) { create(:user, :confirmed, organization:) }
  let!(:high_user_second) { create(:user, :confirmed, organization:) }
  # Create participants with different ponderations
  let!(:basic_participant_first) { create(:participant, setting:, decidim_user: basic_user_first, ponderation: ponderation_low) }
  let!(:basic_participant_second) { create(:participant, setting:, decidim_user: basic_user_second, ponderation: ponderation_low) }
  let!(:high_participant_first) { create(:participant, setting:, decidim_user: high_user_first, ponderation: ponderation_high) }
  let!(:high_participant_second) { create(:participant, setting:, decidim_user: high_user_second, ponderation: ponderation_high) }
  let(:dashboard_path) { Decidim::EngineRouter.admin_proxy(component).dashboard_election_path(election) }

  def create_delegated_vote(question:, response_option:, granter:, grantee:, delegation:)
    vote = create(:election_vote, question:, response_option:, voter_uid: granter.to_global_id.to_s)
    vote.versions.create!(
      item_type: "Decidim::Elections::Vote",
      item_id: vote.id,
      event: "create",
      whodunnit: grantee.id.to_s,
      decidim_action_delegator_delegation_id: delegation.id
    )
    vote
  end

  def create_authorization_for(user, setting)
    create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
  end

  before do
    switch_to_host(organization.host)
    login_as admin, scope: :user

    # Create authorizations for all users to allow them to vote
    create(:authorization, :granted, user: basic_user_first, name: "delegations_verifier", metadata: { setting_id: setting.id })
    create(:authorization, :granted, user: basic_user_second, name: "delegations_verifier", metadata: { setting_id: setting.id })
    create(:authorization, :granted, user: high_user_first, name: "delegations_verifier", metadata: { setting_id: setting.id })
    create(:authorization, :granted, user: high_user_second, name: "delegations_verifier", metadata: { setting_id: setting.id })

    # 2 basic weight users vote for option 1 (2 * 1.0 = 2.0 weighted votes)
    create(:election_vote, question:, response_option: response_option_first, voter_uid: basic_user_first.to_global_id.to_s)
    create(:election_vote, question:, response_option: response_option_first, voter_uid: basic_user_second.to_global_id.to_s)

    # 2 high-weight users vote for option 2 (2 * 3.0 = 6.0 weighted votes)
    create(:election_vote, question:, response_option: response_option_second, voter_uid: high_user_first.to_global_id.to_s)
    create(:election_vote, question:, response_option: response_option_second, voter_uid: high_user_second.to_global_id.to_s)
  end

  context "when visiting admin dashboard results" do
    before { visit dashboard_path }

    it_behaves_like "weighted results navigation"

    context "when viewing by type and weight results" do
      before { click_on "By type and weight" }

      it "shows correct vote counts by ponderation" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("Basic Weight (x1.0)")
          expect(page).to have_content("2 votes")
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("High Weight (x3.0)")
          expect(page).to have_content("2 votes")
        end
      end

      it_behaves_like "live update functionality"
    end

    context "when viewing sum of weights results" do
      before { click_on "Sum of weights" }

      it "shows weighted totals for each option" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("2")
          expect(page).to have_content("25.0%")
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("6")
          expect(page).to have_content("75.0%")
        end
      end

      it_behaves_like "live update functionality"
    end

    context "when viewing totals results" do
      before { click_on "Totals" }

      it "shows correct statistics" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "4 votes")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "8 votes")
          expect(page).to have_css("[data-question-delegated-count-text]", text: "0 votes")
          expect(page).to have_css("[data-question-participants-count-text]", text: "4 participants")
        end
      end

      it_behaves_like "live update functionality"
    end

    context "when different user types vote for same option" do
      before do
        question.votes.destroy_all

        create(:election_vote, question:, response_option: response_option_first, voter_uid: basic_user_first.to_global_id.to_s)
        create(:election_vote, question:, response_option: response_option_first, voter_uid: high_user_first.to_global_id.to_s)

        visit dashboard_path
        click_on "By type and weight"
      end

      it "shows both weight types for same option" do
        within "tr", text: "Basic Weight (x1.0)" do
          expect(page).to have_content(translated(response_option_first.body))
          expect(page).to have_content("1 vote")
        end

        within "tr", text: "High Weight (x3.0)" do
          expect(page).to have_content(translated(response_option_first.body))
          expect(page).to have_content("1 vote")
        end
      end

      it "shows no votes for the other option" do
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("0 votes")
        end
      end
    end

    context "when viewing sum of weights results for same option votes" do
      before do
        click_on "Sum of weights"
      end

      it "shows weighted totals for each option" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("2") # 2 basic-weight votes * 1.0 = 2.0
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("6") # 2 high-weight votes * 3.0 = 6.0
        end
      end

      it "shows percentage distribution" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("25.0%") # 2 out of 8 total weighted votes
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("75.0%") # 6 out of 8 total weighted votes
        end
      end

      it "includes live update functionality" do
        expect(page.html).to include("data-weight-results-live-update")
      end
    end

    context "when viewing totals results for same option votes" do
      before do
        click_on "Totals"
      end

      it "shows unweighted votes count" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "4 votes")
        end
      end

      it "shows weighted votes count" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-weighted-count-text]", text: "8 votes")
        end
      end

      it "shows delegated votes count" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-delegated-count-text]", text: "0 votes")
        end
      end

      it "shows participants count" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-participants-count-text]", text: "4 participants")
        end
      end

      it "includes live update functionality" do
        expect(page.html).to include("data-weight-results-live-update")
      end
    end

    context "when election has no setting configured" do
      let!(:election_without_setting) do
        create(
          :election,
          :published,
          :ongoing,
          :with_questions,
          component:,
          census_manifest: "internal_users"
        )
      end

      before do
        visit_component_admin
        click_on translated(election_without_setting.title)
      end

      it "shows normal decidim results without weighted tabs" do
        expect(page).to have_no_content("By type and weight")
        expect(page).to have_no_content("Sum of weights")
      end
    end
  end

  context "with different question types" do
    let!(:multiple_choice_question) { create(:election_question, :with_response_options, question_type: "multiple_option", election:) }

    before do
      question.votes.destroy_all

      # Basic user votes for the first option of both questions (1.0 weight each)
      create(:election_vote, question:, response_option: response_option_first, voter_uid: basic_user_first.to_global_id.to_s)
      create(:election_vote, question: multiple_choice_question, response_option: multiple_choice_question.response_options.first, voter_uid: basic_user_first.to_global_id.to_s)

      # High user votes for both options of multiple choice question (3.0 weight each)
      create(:election_vote, question: multiple_choice_question, response_option: multiple_choice_question.response_options.first, voter_uid: high_user_first.to_global_id.to_s)
      create(:election_vote, question: multiple_choice_question, response_option: multiple_choice_question.response_options.second, voter_uid: high_user_first.to_global_id.to_s)

      visit dashboard_path
    end

    context "when viewing by type and weight results" do
      before { click_on "By type and weight" }

      it "shows correct vote counts for original question" do
        expect(page).to have_content(translated(question.body))

        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("Basic Weight (x1.0)")
          expect(page).to have_content("1 vote")
        end
      end

      it "shows correct vote counts for multiple choice question" do
        expect(page).to have_content(translated(multiple_choice_question.body))
      end

      it "shows basic weight vote for first option of multiple choice question" do
        within "#question_#{multiple_choice_question.id}" do
          # Since first option appears in 2 rows (basic + high weight), find by weight first
          within "tr", text: "Basic Weight (x1.0)" do
            expect(page).to have_content(translated(multiple_choice_question.response_options.first.body))
            expect(page).to have_content("1 vote")
          end
        end
      end

      it "shows high weight vote for first option of multiple choice question" do
        within "#question_#{multiple_choice_question.id}" do
          # Find the first row with "High Weight (x3.0)" that contains the first option
          within first("tr", text: "High Weight (x3.0)") do
            expect(page).to have_content(translated(multiple_choice_question.response_options.first.body))
            expect(page).to have_content("1 vote")
          end
        end
      end

      it "shows high weight vote for second option of multiple choice question" do
        within "#question_#{multiple_choice_question.id}" do
          # Second option should only appear once with high weight
          within "tr", text: translated(multiple_choice_question.response_options.second.body) do
            expect(page).to have_content("High Weight (x3.0)")
            expect(page).to have_content("1 vote")
          end
        end
      end
    end

    context "when viewing sum of weights results" do
      before { click_on "Sum of weights" }

      it "shows weighted totals for original question" do
        expect(page).to have_content(translated(question.body))

        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("1") # 1 basic-weight vote = 1.0
          expect(page).to have_content("100.0%") # only option with votes
        end
      end

      it "shows weighted totals for multiple choice question" do
        within "tr", text: translated(multiple_choice_question.response_options.first.body) do
          expect(page).to have_content("4") # 1 basic + 1 high = 1.0 + 3.0 = 4.0
          expect(page).to have_content("57.1%") # 4 out of 7 total weighted votes
        end

        within "tr", text: translated(multiple_choice_question.response_options.second.body) do
          expect(page).to have_content("3") # 1 high-weight vote = 3.0
          expect(page).to have_content("42.9%") # 3 out of 7 total weighted votes
        end
      end
    end

    context "when viewing totals results" do
      before { click_on "Totals" }

      it "shows correct statistics for original question" do
        expect(page).to have_content(translated(question.body))
        expect(page).to have_css("[data-question-unweighted-count-text]", text: "1 vote")
        expect(page).to have_css("[data-question-weighted-count-text]", text: "1 vote")
      end

      it "shows correct statistics for multiple choice question" do
        expect(page).to have_content(translated(multiple_choice_question.body))
        expect(page).to have_css("[data-question-unweighted-count-text]", text: "3 votes")
        expect(page).to have_css("[data-question-weighted-count-text]", text: "7 votes")
      end
    end

    context "when viewing by answer results" do
      before { click_on "By answer" }

      it "shows unweighted vote counts" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("1 vote") # 1 unweighted vote
        end

        within "tr", text: translated(multiple_choice_question.response_options.first.body) do
          expect(page).to have_content("2 votes") # 2 unweighted votes
        end

        within "tr", text: translated(multiple_choice_question.response_options.second.body) do
          expect(page).to have_content("1 vote") # 1 unweighted vote
        end
      end
    end
  end

  context "with no votes" do
    before do
      election.questions.each { |q| q.votes.destroy_all }
      visit dashboard_path
    end

    it "shows zero counts in totals results" do
      click_on "Totals"

      expect(page).to have_content(translated(question.body))
      expect(page).to have_css("[data-question-unweighted-count-text]", text: "0 votes")
      expect(page).to have_css("[data-question-weighted-count-text]", text: "0 votes")
      expect(page).to have_css("[data-question-participants-count-text]", text: "0 participants")
      expect(page).to have_css("[data-question-delegated-count-text]", text: "0 votes")
    end

    it "shows zero counts in sum of weights results" do
      click_on "Sum of weights"

      expect(page).to have_content(translated(question.body))

      within "tr", text: translated(response_option_first.body) do
        expect(page).to have_content("0")
        expect(page).to have_content("0.0%")
      end

      within "tr", text: translated(response_option_second.body) do
        expect(page).to have_content("0")
        expect(page).to have_content("0.0%")
      end
    end

    it "shows no weight type rows in by type and weight results" do
      click_on "By type and weight"

      expect(page).to have_content(translated(question.body))
      expect(page).to have_no_content("Basic Weight (x1.0)")
      expect(page).to have_no_content("High Weight (x3.0)")
    end

    it "shows zero counts in standard results" do
      click_on "By answer"

      within "tr", text: translated(response_option_first.body) do
        expect(page).to have_content("0 votes")
      end

      within "tr", text: translated(response_option_second.body) do
        expect(page).to have_content("0 votes")
      end
    end
  end

  context "with per-question elections" do
    let!(:per_question_election) do
      create(
        :election,
        :published,
        :per_question,
        :ongoing,
        component:,
        census_manifest: "internal_users",
        census_settings: {
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {
                "setting" => setting.id.to_s
              }
            }
          }
        }
      )
    end

    let!(:pq_question_enabled) { create(:election_question, :with_response_options, :voting_enabled, election: per_question_election) }
    let!(:pq_question_disabled) { create(:election_question, :with_response_options, election: per_question_election) }
    let(:pq_dashboard_path) { Decidim::EngineRouter.admin_proxy(component).dashboard_election_path(per_question_election) }

    before do
      create(:election_vote, question: pq_question_enabled, response_option: pq_question_enabled.response_options.first, voter_uid: basic_user_first.to_global_id.to_s)
      create(:election_vote, question: pq_question_enabled, response_option: pq_question_enabled.response_options.second, voter_uid: high_user_first.to_global_id.to_s)
    end

    context "when viewing dashboard" do
      before do
        visit pq_dashboard_path
      end


      it "shows both enabled and disabled questions" do
        expect(page).to have_content(translated(pq_question_enabled.body))
        expect(page).to have_content(translated(pq_question_disabled.body))
      end
    end

    context "when viewing by type and weight results" do
      before do
        visit pq_dashboard_path
        click_on "By type and weight"
      end

      it "shows results only for questions with votes" do
        expect(page).to have_content(translated(pq_question_enabled.body))

        within "tr", text: translated(pq_question_enabled.response_options.first.body) do
          expect(page).to have_content("Basic Weight (x1.0)")
          expect(page).to have_content("1 vote")
        end

        within "tr", text: translated(pq_question_enabled.response_options.second.body) do
          expect(page).to have_content("High Weight (x3.0)")
          expect(page).to have_content("1 vote")
        end
      end

      it "shows no weight type rows for questions without votes" do
        expect(page).to have_content(translated(pq_question_disabled.body))

        within "tr", text: translated(pq_question_disabled.response_options.first.body) do
          expect(page).to have_content("-")
          expect(page).to have_content("0 votes")
        end

        within "tr", text: translated(pq_question_disabled.response_options.second.body) do
          expect(page).to have_content("-")
          expect(page).to have_content("0 votes")
        end
      end
    end

    context "when viewing sum of weights results" do
      before do
        visit pq_dashboard_path
        click_on "Sum of weights"
      end

      it "shows weighted totals for enabled question" do
        within "tr", text: translated(pq_question_enabled.response_options.first.body) do
          expect(page).to have_content("1") # 1 basic-weight vote = 1.0
          expect(page).to have_content("25.0%") # 1 out of 4 total weighted votes
        end

        within "tr", text: translated(pq_question_enabled.response_options.second.body) do
          expect(page).to have_content("3") # 1 high-weight vote = 3.0
          expect(page).to have_content("75.0%") # 3 out of 4 total weighted votes
        end
      end

      it "shows zero counts for disabled question" do
        within "tr", text: translated(pq_question_disabled.response_options.first.body) do
          expect(page).to have_content("0")
          expect(page).to have_content("0.0%")
        end

        within "tr", text: translated(pq_question_disabled.response_options.second.body) do
          expect(page).to have_content("0")
          expect(page).to have_content("0.0%")
        end
      end
    end

    context "when viewing totals results" do
      before do
        visit pq_dashboard_path
        click_on "Totals"
      end

      it "shows correct statistics for enabled question" do
        within "tr", text: translated(pq_question_enabled.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "2 votes")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "4 votes")
          expect(page).to have_css("[data-question-delegated-count-text]", text: "0 votes")
          expect(page).to have_css("[data-question-participants-count-text]", text: "2 participants")
        end
      end

      it "shows zero statistics for disabled question" do
        within "tr", text: translated(pq_question_disabled.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "0 votes")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "0 votes")
          expect(page).to have_css("[data-question-delegated-count-text]", text: "0 votes")
          expect(page).to have_css("[data-question-participants-count-text]", text: "0 participants")
        end
      end
    end

    context "when viewing by answer results" do
      before do
        visit pq_dashboard_path
        click_on "By answer"
      end

      it "shows unweighted vote counts for enabled question" do
        within "tr", text: translated(pq_question_enabled.response_options.first.body) do
          expect(page).to have_content("1 vote")
        end

        within "tr", text: translated(pq_question_enabled.response_options.second.body) do
          expect(page).to have_content("1 vote")
        end
      end

      it "shows zero vote counts for disabled question" do
        within "tr", text: translated(pq_question_disabled.response_options.first.body) do
          expect(page).to have_content("0 votes")
        end

        within "tr", text: translated(pq_question_disabled.response_options.second.body) do
          expect(page).to have_content("0 votes")
        end
      end
    end
  end

  context "with delegated votes" do
    # Create additional users for delegation scenarios
    let!(:granter_basic) { create(:user, :confirmed, organization:) }
    let!(:granter_high) { create(:user, :confirmed, organization:) }
    let!(:grantee_basic) { create(:user, :confirmed, organization:) }
    let!(:grantee_high) { create(:user, :confirmed, organization:) }

    # Create participants for delegation users
    let!(:granter_basic_participant) { create(:participant, setting:, decidim_user: granter_basic, ponderation: ponderation_low) }
    let!(:granter_high_participant) { create(:participant, setting:, decidim_user: granter_high, ponderation: ponderation_high) }
    let!(:grantee_basic_participant) { create(:participant, setting:, decidim_user: grantee_basic, ponderation: ponderation_low) }
    let!(:grantee_high_participant) { create(:participant, setting:, decidim_user: grantee_high, ponderation: ponderation_high) }

    # Create delegations
    let!(:delegation_basic_to_basic) { create(:delegation, setting:, granter: granter_basic, grantee: grantee_basic) }
    let!(:delegation_high_to_high) { create(:delegation, setting:, granter: granter_high, grantee: grantee_high) }

    before do
      election.questions.each { |q| q.votes.destroy_all }

      # Create authorizations for delegation users
      create(:authorization, :granted, user: granter_basic, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: granter_high, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: grantee_basic, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: grantee_high, name: "delegations_verifier", metadata: { setting_id: setting.id })

      # Scenario: Both granter and grantee vote
      # 1. Direct vote by basic weight user (1.0 weight)
      create(:election_vote, question:, response_option: response_option_first, voter_uid: basic_user_first.to_global_id.to_s)

      # 2. Direct vote by high weight user (3.0 weight)
      create(:election_vote, question:, response_option: response_option_second, voter_uid: high_user_first.to_global_id.to_s)

      # 3. Delegated vote: grantee_basic votes for granter_basic (1.0 weight, delegated)
      delegated_vote_basic = create(:election_vote, question:, response_option: response_option_first, voter_uid: granter_basic.to_global_id.to_s)
      delegated_vote_basic.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote_basic.id,
        event: "create",
        whodunnit: grantee_basic.id.to_s,
        decidim_action_delegator_delegation_id: delegation_basic_to_basic.id
      )

      # 4. Delegated vote: grantee_high votes for granter_high (3.0 weight, delegated)
      delegated_vote_high = create(:election_vote, question:, response_option: response_option_second, voter_uid: granter_high.to_global_id.to_s)
      delegated_vote_high.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote_high.id,
        event: "create",
        whodunnit: grantee_high.id.to_s,
        decidim_action_delegator_delegation_id: delegation_high_to_high.id
      )

      # 5. Direct vote by grantee_basic (their own 1.0 weight vote)
      create(:election_vote, question:, response_option: response_option_first, voter_uid: grantee_basic.to_global_id.to_s)

      # 6. Direct vote by grantee_high (their own 3.0 weight vote)
      create(:election_vote, question:, response_option: response_option_second, voter_uid: grantee_high.to_global_id.to_s)

      visit dashboard_path
    end

    context "when viewing by type and weight results" do
      before { click_on "By type and weight" }

      it "shows correct vote counts including both direct and delegated votes" do
        # Option 1: 3 basic weight votes (1 direct + 1 delegated + 1 grantee direct)
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("Basic Weight (x1.0)")
          expect(page).to have_content("3 votes")
        end

        # Option 2: 3 high weight votes (1 direct + 1 delegated + 1 grantee direct)
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("High Weight (x3.0)")
          expect(page).to have_content("3 votes")
        end
      end
    end

    context "when viewing sum of weights results" do
      before { click_on "Sum of weights" }

      it "shows correct weighted totals including delegated votes" do
        # Option 1: 3 basic weight votes = 3.0 total weight
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("3") # 3 * 1.0 = 3.0
          expect(page).to have_content("25.0%") # 3 out of 12 total weighted votes
        end

        # Option 2: 3 high weight votes = 9.0 total weight
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("9") # 3 * 3.0 = 9.0
          expect(page).to have_content("75.0%") # 9 out of 12 total weighted votes
        end
      end
    end

    context "when viewing totals results" do
      before { click_on "Totals" }

      it "shows correct statistics including delegated vote count" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "6 votes")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "12 votes")
          expect(page).to have_css("[data-question-delegated-count-text]", text: "2 votes")
          expect(page).to have_css("[data-question-participants-count-text]", text: "6 participants")
        end
      end
    end

    context "when viewing by answer results" do
      before { click_on "By answer" }

      it "shows unweighted vote counts including delegated votes" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("3 votes") # 3 unweighted votes
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("3 votes") # 3 unweighted votes
        end
      end
    end
  end

  context "with participants without ponderation and delegated votes" do
    # Users without ponderation (weight defaults to 1.0)
    let!(:no_ponderation_user_first) { create(:user, :confirmed, organization:) }
    let!(:no_ponderation_user_second) { create(:user, :confirmed, organization:) }
    let!(:regular_user) { create(:user, :confirmed, organization:) }

    # Create participants without ponderation (nil ponderation)
    let!(:no_ponderation_participant_first) { create(:participant, setting:, decidim_user: no_ponderation_user_first, ponderation: nil) }
    let!(:no_ponderation_participant_second) { create(:participant, setting:, decidim_user: no_ponderation_user_second, ponderation: nil) }
    let!(:regular_participant) { create(:participant, setting:, decidim_user: regular_user, ponderation: ponderation_low) }

    # Create delegation: no_ponderation_user_first delegates to no_ponderation_user_second
    let!(:delegation_no_ponderation) { create(:delegation, setting:, granter: no_ponderation_user_first, grantee: no_ponderation_user_second) }

    before do
      # Clear existing votes
      election.questions.each { |q| q.votes.destroy_all }

      # Create authorizations
      create(:authorization, :granted, user: no_ponderation_user_first, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: no_ponderation_user_second, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: regular_user, name: "delegations_verifier", metadata: { setting_id: setting.id })

      # 1. Delegated vote: no_ponderation_user_second votes for no_ponderation_user_first (1.0 weight, delegated)
      delegated_vote = create(:election_vote, question:, response_option: response_option_first, voter_uid: no_ponderation_user_first.to_global_id.to_s)
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: no_ponderation_user_second.id.to_s,
        decidim_action_delegator_delegation_id: delegation_no_ponderation.id
      )

      # 2. Direct vote by no_ponderation_user_second (their own 1.0 weight vote)
      create(:election_vote, question:, response_option: response_option_first, voter_uid: no_ponderation_user_second.to_global_id.to_s)

      # 3. Direct vote by regular_user with ponderation (1.0 weight)
      create(:election_vote, question:, response_option: response_option_second, voter_uid: regular_user.to_global_id.to_s)

      visit dashboard_path
    end

    context "when viewing by type and weight results" do
      before { click_on "By type and weight" }

      it "groups users without ponderation together with default weight" do
        # Option 1: should have 2 votes (1 delegated + 1 direct from users without ponderation)
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("2 votes")
          expect(page).to have_content("-") # Users without ponderation show as "-"
        end

        # Option 2: should have 1 vote from user with ponderation
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("1 vote")
          expect(page).to have_content("Basic Weight (x1.0)")
        end
      end
    end

    context "when viewing sum of weights results" do
      before { click_on "Sum of weights" }

      it "shows correct weighted totals for users without ponderation" do
        # Option 1: 2 votes without ponderation = 2.0 total weight
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("2") # 2 * 1.0 = 2.0
          expect(page).to have_content("66.7%") # 2 out of 3 total weighted votes
        end

        # Option 2: 1 vote with basic weight = 1.0 total weight
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("1") # 1 * 1.0 = 1.0
          expect(page).to have_content("33.3%") # 1 out of 3 total weighted votes
        end
      end
    end

    context "when viewing totals results" do
      before { click_on "Totals" }

      it "shows correct statistics including delegated and non-ponderation votes" do
        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "3 votes") # Total unweighted votes
          expect(page).to have_css("[data-question-weighted-count-text]", text: "3 votes") # Total weighted votes (all 1.0)
          expect(page).to have_css("[data-question-delegated-count-text]", text: "1 vote") # Only 1 delegated vote
          expect(page).to have_css("[data-question-participants-count-text]", text: "3 participants") # 3 unique voter_uids
        end
      end
    end

    context "when viewing by answer results" do
      before { click_on "By answer" }

      it "shows unweighted vote counts including users without ponderation" do
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("2 votes") # 2 unweighted votes
        end

        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("1 vote") # 1 unweighted vote
        end
      end
    end
  end

  context "with complex delegation scenarios" do
    let!(:delegator_user) { create(:user, :confirmed, organization:) }
    let!(:delegate_user) { create(:user, :confirmed, organization:) }
    let!(:delegator_participant) { create(:participant, setting:, decidim_user: delegator_user, ponderation: ponderation_high) }
    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user, ponderation: ponderation_low) }
    let!(:delegation) { create(:delegation, setting:, granter: delegator_user, grantee: delegate_user) }

    before do
      election.questions.each { |q| q.votes.destroy_all }
      create(:authorization, :granted, user: delegator_user, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata: { setting_id: setting.id })
    end

    context "when only delegated vote exists (delegator doesn't vote directly)" do
      before do
        # Only delegated vote: delegate votes for delegator (high weight)
        delegated_vote = create(:election_vote, question:, response_option: response_option_first, voter_uid: delegator_user.to_global_id.to_s)
        delegated_vote.versions.create!(
          item_type: "Decidim::Elections::Vote",
          item_id: delegated_vote.id,
          event: "create",
          whodunnit: delegate_user.id.to_s,
          decidim_action_delegator_delegation_id: delegation.id
        )

        visit dashboard_path
      end

      it "shows delegated vote with delegator's weight in by type and weight view" do
        click_on "By type and weight"

        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("High Weight (x3.0)") # Uses delegator's weight
          expect(page).to have_content("1 vote")
        end
      end

      it "shows delegated vote statistics in totals view" do
        click_on "Totals"

        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "1 vote")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "3 votes") # 1 * 3.0 weight
          expect(page).to have_css("[data-question-delegated-count-text]", text: "1 vote") # 1 delegated vote
          expect(page).to have_css("[data-question-participants-count-text]", text: "1 participant") # 1 unique voter_uid
        end
      end
    end

    context "when delegate votes both for themselves and delegator" do
      before do
        # 1. Delegate votes for themselves (basic weight)
        create(:election_vote, question:, response_option: response_option_first, voter_uid: delegate_user.to_global_id.to_s)

        # 2. Delegate votes for delegator (high weight, delegated)
        delegated_vote = create(:election_vote, question:, response_option: response_option_second, voter_uid: delegator_user.to_global_id.to_s)
        delegated_vote.versions.create!(
          item_type: "Decidim::Elections::Vote",
          item_id: delegated_vote.id,
          event: "create",
          whodunnit: delegate_user.id.to_s,
          decidim_action_delegator_delegation_id: delegation.id
        )

        visit dashboard_path
      end

      it "shows both votes with correct weights in by type and weight view" do
        click_on "By type and weight"

        # Delegate's own vote (basic weight)
        within "tr", text: translated(response_option_first.body) do
          expect(page).to have_content("Basic Weight (x1.0)")
          expect(page).to have_content("1 vote")
        end

        # Delegated vote (high weight)
        within "tr", text: translated(response_option_second.body) do
          expect(page).to have_content("High Weight (x3.0)")
          expect(page).to have_content("1 vote")
        end
      end

      it "shows correct totals with mixed direct and delegated votes" do
        click_on "Totals"

        within "tr", text: translated(question.body) do
          expect(page).to have_css("[data-question-unweighted-count-text]", text: "2 votes")
          expect(page).to have_css("[data-question-weighted-count-text]", text: "4 votes") # 1*1.0 + 1*3.0 = 4.0
          expect(page).to have_css("[data-question-delegated-count-text]", text: "1 vote") # Only 1 delegated vote
          expect(page).to have_css("[data-question-participants-count-text]", text: "2 participants") # 2 unique voter_uids
        end
      end
    end
  end
end
