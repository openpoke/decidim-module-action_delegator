# frozen_string_literal: true

require "spec_helper"

describe "User votes in elections with multiple settings" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, :published, organization:) }
  let(:user) { create(:user, :confirmed, organization:, email: "voter@example.com", name: "Test Voter") }
  let(:other_user) { create(:user, :confirmed, organization:, email: "other@example.com", name: "Other User") }
  let(:invalid_user) { create(:user, :confirmed, organization:, email: "invalid@example.com", name: "Invalid User") }

  let!(:setting1) { create(:setting, organization:, title: { en: "Setting 1" }, active: true, authorization_method: :email) }
  let!(:setting2) { create(:setting, organization:, title: { en: "Setting 2" }, active: true, authorization_method: :email) }

  let!(:participant_in_setting1) { create(:participant, setting: setting1, email: user.email) }
  let!(:participant_in_setting2) { create(:participant, setting: setting2, email: user.email) }
  let!(:invalid_participant_in_setting2) { create(:participant, setting: setting2, email: invalid_user.email) }

  let(:census_settings1) { { "authorization_handlers" => { "delegations_verifier" => { "options" => { "setting" => setting1.id.to_s } } } } }
  let(:census_settings2) { { "setting_id" => setting2.id.to_s, "authorization_handlers" => { "delegations_verifier" => { "options" => {} } } } }

  let!(:election1) { create(:election, :published, :ongoing, :with_questions, component:, title: { en: "Election 1" }, census_manifest: "internal_users", census_settings: census_settings1) }
  let!(:election2) { create(:election, :published, :ongoing, :with_questions, component:, title: { en: "Election 2" }, census_manifest: "action_delegator_census", census_settings: census_settings2) }

  before do
    switch_to_host(organization.host)
  end

  def visit_election(election)
    visit Decidim::EngineRouter.main_proxy(component).election_path(election)
  end

  context "when user is participant in all settings" do
    before do
      login_as user, scope: :user
    end

    it "can vote in all elections after single verification", :slow do
      visit_election(election1)
      click_on "Vote"

      expect(page).to have_content("Verify your identity")
      click_on "Verify with Corporate Governance"

      expect(page).to have_content("successfully verified")
      expect(page).to have_content(translated(election1.questions.first.body))

      visit_election(election2)
      click_on "Vote"
      expect(page).to have_content(translated(election2.questions.first.body))
    end
  end

  context "when user is not in participants" do
    before do
      login_as other_user, scope: :user
    end

    it "cannot vote in any election", :slow do
      visit_election(election1)
      click_on "Vote"

      expect(page).to have_content("Verify your identity")
      click_on "Verify with Corporate Governance"

      expect(page).to have_content("not in the census")

      visit_election(election1)
      click_on "Vote"
      expect(page).to have_content("Verify your identity")
      expect(page).to have_no_content(translated(election1.questions.first.body))

      visit_election(election2)
      click_on "Vote"
      expect(page).to have_content("Verify your identity")
      expect(page).to have_no_content(translated(election2.questions.first.body))
    end
  end

  context "when user is participant in only one setting" do
    before do
      login_as invalid_user, scope: :user
    end

    it "can vote only in the election with that setting", :slow do
      visit_election(election1)
      click_on "Vote"

      expect(page).to have_content("Verify your identity")
      click_on "Verify with Corporate Governance"

      expect(page).to have_content("successfully verified")
      expect(page).to have_content("You are not authorized to vote in this election.")
      expect(page).to have_no_content(translated(election1.questions.first.body))

      visit_election(election1)
      click_on "Vote"
      expect(page).to have_content("Verify your identity")
      expect(page).to have_no_content(translated(election1.questions.first.body))

      visit_election(election2)
      click_on "Vote"

      expect(page).to have_content(translated(election2.questions.first.body))
    end
  end
end
