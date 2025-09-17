# frozen_string_literal: true

require "spec_helper"

describe "Delegated voting in elections" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, organization:) }

  def election_per_question_vote_path(question_id, delegation_id = nil)
    path = Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: question_id)
    delegation_id ? "#{path}?delegation=#{delegation_id}" : path
  end

  context "when election is per_question type" do
    let(:user) { create(:user, :confirmed, organization:) }
    let(:delegate_user) { create(:user, :confirmed, organization:) }
    let(:setting) { create(:setting, organization: component.organization) }
    let!(:user_participant) { create(:participant, setting:, decidim_user: user) }
    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user) }
    let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }
    let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(election) }
    let(:waiting_election_per_question_votes_path) { Decidim::EngineRouter.main_proxy(component).waiting_election_per_question_votes_path(election_id: election.id) }

    let!(:election) do
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

    let!(:current_question) { create(:election_question, :with_response_options, :voting_enabled, election:) }
    let!(:next_question) { create(:election_question, :with_response_options, election:) }

    before do
      switch_to_host(organization.host)
      create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
      create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata: { setting_id: setting.id })
    end

    context "when delegate user sees delegation options" do
      before do
        login_as delegate_user, scope: :user
        visit election_path
      end

      it "shows delegation sidebar on election page" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes.")
        expect(page).to have_content("You can vote on behalf of the following participants in this election:")

        within ".election__aside-voted" do
          expect(page).to have_content(user.name.to_s)
        end
      end
    end

    context "when delegate votes for themselves first" do
      before do
        login_as delegate_user, scope: :user
      end

      it "shows self-voting message and allows voting" do
        visit election_per_question_vote_path(current_question.id)
        expect(page).to have_content("You are voting for yourself (#{delegate_user.name})")

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_content("Waiting for the next question")

        expect(page).to have_css(".waiting-buttons")
        expect(page).to have_content("You have delegated votes.")
        expect(page).to have_link(
          "Continue voting on behalf of #{user.name}",
          href: election_per_question_vote_path(current_question.id, delegation.id)
        )
      end
    end

    context "when delegate votes on behalf of delegated user" do
      before do
        login_as delegate_user, scope: :user
      end

      it "shows delegation voting message and allows voting" do
        visit election_per_question_vote_path(current_question.id, delegation.id)
        expect(page).to have_content("You are voting on behalf of #{user.name}")

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end

      it "shows edit vote option after voting for delegated user" do
        visit election_per_question_vote_path(current_question.id, delegation.id)
        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
        expect(page).to have_content("You are voting for yourself")

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_content("Waiting for the next question")
      end
    end

    context "when delegate votes for themselves after delegation" do
      before do
        login_as delegate_user, scope: :user
        visit election_per_question_vote_path(current_question.id, delegation.id)
        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"
      end

      it "shows edit own vote option" do
        visit election_per_question_vote_path(current_question.id)
        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_link("Edit your vote", href: election_per_question_vote_path(current_question.id))
      end
    end

    context "when tracking delegation state across questions" do
      before do
        login_as delegate_user, scope: :user
      end

      it "maintains delegation ID in session" do
        visit election_per_question_vote_path(current_question.id, delegation.id)
        expect(page).to have_content("You are voting on behalf of #{user.name}")

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
        expect(page).to have_content("You are voting for yourself")

        visit election_per_question_vote_path(current_question.id, delegation.id)
        expect(page).to have_content("You are voting on behalf of #{user.name}")
      end
    end

    context "when delegate has voted for delegated user" do
      before do
        login_as delegate_user, scope: :user
        visit election_per_question_vote_path(current_question.id, delegation.id)
        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"
        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Cast vote"
      end

      it "shows voted status on election page" do
        visit election_path

        expect(page).to have_content("You have delegated votes.")
        expect(page).to have_content("You can vote on behalf of the following participants in this election:")

        within all(".election__aside-voted").last do
          expect(page).to have_content("✔ #{user.name}")
        end
      end
    end
  end

  context "when election is normal (not per_question) type" do
    let(:user2) { create(:user, :confirmed, organization:) }
    let(:delegate_user2) { create(:user, :confirmed, organization:) }
    let(:setting2) { create(:setting, organization: component.organization) }
    let!(:user_participant2) { create(:participant, setting: setting2, decidim_user: user2) }
    let!(:delegate_participant2) { create(:participant, setting: setting2, decidim_user: delegate_user2) }
    let!(:delegation2) { create(:delegation, setting: setting2, granter: user2, grantee: delegate_user2) }
    let(:election2) do
      create(
        :election,
        :published,
        :ongoing,
        :with_internal_users_census,
        component:,
        census_settings: {
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {
                "setting" => setting2.id.to_s
              }
            }
          }
        }
      )
    end
    let(:election_path2) { Decidim::EngineRouter.main_proxy(component).election_path(election2) }
    let!(:question) { create(:election_question, :with_response_options, :voting_enabled, election: election2) }

    before do
      switch_to_host(organization.host)
      create(:authorization, :granted, user: user2, name: "delegations_verifier", metadata: { setting_id: setting2.id })
      create(:authorization, :granted, user: delegate_user2, name: "delegations_verifier", metadata: { setting_id: setting2.id })
    end

    context "when delegate user visits election page" do
      before do
        login_as delegate_user2, scope: :user
        visit election_path2
      end

      it "shows normal election delegation buttons" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes.")

        within ".election__aside-voted" do
          expect(page).to have_content(user2.name)
        end
      end
    end
  end

  context "when user has no delegations" do
    let(:user_without_delegations) { create(:user, :confirmed, organization:) }
    let(:setting3) { create(:setting, organization: component.organization) }
    let(:election_path3) { Decidim::EngineRouter.main_proxy(component).election_path(election3) }

    let(:election3) do
      create(
        :election,
        :published,
        :ongoing,
        :with_internal_users_census,
        component:,
        census_settings: {
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {
                "setting" => setting3.id.to_s
              }
            }
          }
        }
      )
    end

    before do
      switch_to_host(organization.host)
      create(:authorization, :granted, user: user_without_delegations, name: "delegations_verifier", metadata: { setting_id: setting3.id })
      login_as user_without_delegations, scope: :user
      visit election_path3
    end

    it "does not show delegation buttons" do
      expect(page).to have_no_css(".election__aside-voted")
      expect(page).to have_no_content("You have delegated votes.")
    end
  end

  context "when election is not ongoing" do
    let(:user4) { create(:user, :confirmed, organization:) }
    let(:delegate_user4) { create(:user, :confirmed, organization:) }
    let(:setting4) { create(:setting, organization: component.organization) }
    let!(:user_participant4) { create(:participant, setting: setting4, decidim_user: user4) }
    let!(:delegate_participant4) { create(:participant, setting: setting4, decidim_user: delegate_user4) }
    let!(:delegation4) { create(:delegation, setting: setting4, granter: user4, grantee: delegate_user4) }
    let(:election4) do
      create(
        :election,
        :published,
        :finished,
        :with_internal_users_census,
        component:,
        census_settings: {
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {
                "setting" => setting4.id.to_s
              }
            }
          }
        }
      )
    end
    let(:election_path4) { Decidim::EngineRouter.main_proxy(component).election_path(election4) }

    before do
      switch_to_host(organization.host)
      create(:authorization, :granted, user: user4, name: "delegations_verifier", metadata: { setting_id: setting4.id })
      create(:authorization, :granted, user: delegate_user4, name: "delegations_verifier", metadata: { setting_id: setting4.id })
      login_as delegate_user4, scope: :user
      visit election_path4
    end

    it "does not show delegation buttons" do
      expect(page).to have_no_css(".election__aside-voted")
      expect(page).to have_no_content("You have delegated votes.")
    end
  end

  context "when election results are published" do
    let(:user5) { create(:user, :confirmed, organization:) }
    let(:delegate_user5) { create(:user, :confirmed, organization:) }
    let(:setting5) { create(:setting, organization: component.organization) }
    let!(:user_participant5) { create(:participant, setting: setting5, decidim_user: user5) }
    let!(:delegate_participant5) { create(:participant, setting: setting5, decidim_user: delegate_user5) }
    let!(:delegation5) { create(:delegation, setting: setting5, granter: user5, grantee: delegate_user5) }
    let(:election5) do
      create(
        :election,
        :published,
        :finished,
        :with_internal_users_census,
        component:,
        census_settings: {
          "authorization_handlers" => {
            "delegations_verifier" => {
              "options" => {
                "setting" => setting5.id.to_s
              }
            }
          }
        },
        published_results_at: 1.day.ago
      )
    end
    let(:election_path5) { Decidim::EngineRouter.main_proxy(component).election_path(election5) }

    before do
      switch_to_host(organization.host)
      create(:authorization, :granted, user: user5, name: "delegations_verifier", metadata: { setting_id: setting5.id })
      create(:authorization, :granted, user: delegate_user5, name: "delegations_verifier", metadata: { setting_id: setting5.id })
      login_as delegate_user5, scope: :user
      visit election_path5
    end

    it "does not show any voting interface or delegation buttons when results are published" do
      expect(page).to have_no_link("Vote")
      expect(page).to have_no_css(".election__aside-voted")
      expect(page).to have_no_content("You have delegated votes.")
      expect(page).to have_no_content("You can vote on behalf of the following participants in this election:")
      expect(page).to have_no_content("You have already voted")
      expect(page).to have_no_content("You are voting for yourself")
      expect(page).to have_no_content("You are voting on behalf of")
    end
  end
end
