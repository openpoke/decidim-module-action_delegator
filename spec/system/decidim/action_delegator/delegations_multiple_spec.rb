# frozen_string_literal: true

require "spec_helper"

describe "Delegation vote in elections" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, organization:) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:granter) { create(:user, :confirmed, organization:) }
  let(:setting) { create(:setting, organization:, authorization_method: :email, active: true, skip_injection: true) }
  let!(:user_participant) { create(:participant, setting:, email: user.email) }
  let!(:granter_participant) { create(:participant, setting:, email: granter.email) }
  let!(:delegation) { create(:delegation, setting:, granter:, grantee: user) }

  let!(:election) do
    create(
      :election,
      :published,
      :ongoing,
      :per_question,
      component:,
      census_manifest: "action_delegator_census",
      census_settings: {
        "setting_id" => setting.id.to_s,
        "authorization_handlers" => { "delegations_verifier" => { "options" => {} } }
      }
    )
  end

  let!(:question) { create(:election_question, :voting_enabled, skip_injection: true, election:, question_type: "multiple_option") }
  let!(:response1) { create(:election_response_option, question:, body: { en: "Response 1" }) }
  let!(:response2) { create(:election_response_option, question:, body: { en: "Response 2" }) }
  let!(:response3) { create(:election_response_option, question:, body: { en: "Response 3" }) }

  let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(election) }
  let(:question_vote_path) { Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: question.id) }

  before do
    switch_to_host(organization.host)
  end

  context "when unauthenticated user" do
    it "renders the election page" do
      visit election_path

      expect(page).to have_content("Vote")
    end
  end

  context "when authenticated user" do
    before do
      login_as user, scope: :user
    end

    context "and delegation is not voted" do
      context "and the user verification is not fulfilled" do
        before do
          visit election_path
        end

        it "requires verification first" do
          click_on "Vote"

          expect(page).to have_content("Verify your identity")
        end
      end

      context "and the user verification is fulfilled" do
        before do
          create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
          visit election_path
        end

        it "lets the user vote on behalf of another member" do
          click_on "Vote"

          find("input[value='#{response1.id}']").click
          find("input[value='#{response2.id}']").click
          click_on "Cast vote"

          expect(page).to have_link("Continue voting on behalf of #{granter.name}", href: "#{question_vote_path}?delegation=#{delegation.id}")

          click_on "Continue voting on behalf of #{granter.name}"
          find("input[value='#{response1.id}']").click
          find("input[value='#{response2.id}']").click
          click_on "Cast vote"

          expect(page).to have_content("Your vote has been successfully cast")
        end
      end
    end

    context "and delegation is voted" do
      before do
        create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
        create(:election_vote, question:, response_option: response1, voter_uid: granter.to_global_id.to_s)
        create(:election_vote, question:, response_option: response2, voter_uid: granter.to_global_id.to_s)
        visit election_path
      end

      it "shows the delegated member as already voted" do
        expect(page).to have_content("You have delegated votes.")

        within all(".election__aside-voted").last do
          expect(page).to have_content("✔ #{granter.name}")
        end
      end
    end
  end
end
