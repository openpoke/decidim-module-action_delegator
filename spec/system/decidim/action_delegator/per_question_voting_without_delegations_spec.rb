# frozen_string_literal: true

require "spec_helper"

describe "Per question voting without delegations" do
  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:elections_component, participatory_space: participatory_process) }
  let!(:election) { create(:election, :published, :ongoing, :with_token_csv_census, :per_question, component:) }
  let!(:question1) { create(:election_question, :with_response_options, :voting_enabled, question_type: "single_option", election:, position: 1) }
  let!(:question2) { create(:election_question, :with_response_options, election:, position: 2) }
  let(:voter) { election.voters.first }
  let(:email) { voter.data["email"] }
  let(:token) { voter.data["token"] }

  let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(election) }
  let(:new_vote_path) { Decidim::EngineRouter.main_proxy(component).new_election_per_question_vote_path(election_id: election.id) }
  let(:waiting_path) { Decidim::EngineRouter.main_proxy(component).waiting_election_per_question_votes_path(election_id: election.id) }
  let(:receipt_path) { Decidim::EngineRouter.main_proxy(component).receipt_election_per_question_votes_path(election_id: election.id) }

  before do
    switch_to_host(organization.host)
  end

  context "when guest user completes per-question voting" do
    it "votes on all questions without delegation errors" do
      visit election_path

      click_on "Vote"

      fill_in "Email", with: email
      fill_in "Token", with: token
      click_on "Access"

      expect(page).to have_content(question1.body["en"])

      first_option = question1.response_options.first
      find("input[value='#{first_option.id}']").click
      click_on "Cast vote"

      expect(page).to have_current_path(waiting_path)
      expect(page).to have_content("Waiting for the next question")
      expect(page).to have_no_content("You have delegated votes")

      question2.update!(voting_enabled_at: Time.current)

      visit waiting_path

      expect(page).to have_content(question2.body["en"])

      second_option = question2.response_options.first
      find("input[value='#{second_option.id}']").click
      click_on "Cast vote"

      expect(page).to have_current_path(receipt_path)
      expect(page).to have_content("Your vote has been successfully cast")
    end
  end

  context "when logged in user completes per-question voting" do
    let(:user) { create(:user, :confirmed, organization:) }

    before do
      login_as user, scope: :user
    end

    it "votes on all questions without delegation errors" do
      visit election_path

      click_on "Vote"

      fill_in "Email", with: email
      fill_in "Token", with: token
      click_on "Access"

      expect(page).to have_content(question1.body["en"])

      first_option = question1.response_options.first
      find("input[value='#{first_option.id}']").click
      click_on "Cast vote"

      expect(page).to have_current_path(waiting_path)
      expect(page).to have_content("Waiting for the next question")
      expect(page).to have_no_content("You have delegated votes")

      question2.update!(voting_enabled_at: Time.current)

      visit waiting_path

      expect(page).to have_content(question2.body["en"])

      second_option = question2.response_options.first
      find("input[value='#{second_option.id}']").click
      click_on "Cast vote"

      expect(page).to have_current_path(receipt_path)
      expect(page).to have_content("Your vote has been successfully cast")
    end
  end
end
