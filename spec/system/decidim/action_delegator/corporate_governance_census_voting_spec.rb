# frozen_string_literal: true

require "spec_helper"

describe "Corporate governance census voting" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, organization:) }
  let(:setting) { create(:setting, organization: component.organization) }

  def election_path
    Decidim::EngineRouter.main_proxy(component).election_path(election)
  end

  def election_per_question_vote_path(question_id, delegation_id = nil)
    path = Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: question_id)
    delegation_id ? "#{path}?delegation=#{delegation_id}" : path
  end

  before do
    switch_to_host(organization.host)
  end

  context "when election uses corporate_governance_census without handlers" do
    let!(:election) do
      create(
        :election,
        :published,
        :ongoing,
        component:,
        census_manifest: "corporate_governance_census",
        census_settings: {
          "setting_id" => setting.id.to_s
        }
      )
    end

    let!(:question) { create(:election_question, :with_response_options, :voting_enabled, election:) }

    # TODO: this needs to be clarified
    context "when user is participant in setting" do
      let(:user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }

      before do
        login_as user, scope: :user
        visit election_path
      end

      it "allows voting without authorization" do
        click_on "Vote"

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Next"
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end

      it "shows election details without delegation options" do
        expect(page).to have_link("Vote")
        expect(page).to have_no_css(".election__aside-voted")
        expect(page).to have_no_content("You have delegated votes")
      end
    end

    context "when user is delegate (grantee) in setting" do
      let(:user) { create(:user, :confirmed, organization:) }
      let(:delegate_user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }
      let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user) }
      let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }

      before do
        login_as delegate_user, scope: :user
        visit election_path
      end

      it "shows delegation options in sidebar" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes.")
        expect(page).to have_content("👉 Vote on behalf of")

        within ".election__aside-voted" do
          expect(page).to have_content(user.name.to_s)
        end
      end

      it "allows voting for themselves" do
        click_on "Vote"

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Next"
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end

      it "allows voting on behalf of delegated user" do
        click_on user.name.to_s

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Next"
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end
    end

    context "when user is not in setting (no participant or delegate)" do
      let(:user) { create(:user, :confirmed, organization:) }

      before do
        login_as user, scope: :user
        visit election_path
      end

      it "does not show voting options" do
        # expect(page).to have_no_link("Vote") # TODO: needs clarification
        expect(page).to have_no_content("👉 Vote on behalf of")
        expect(page).to have_no_css(".election__aside-voted")
      end
    end

    context "when visitor is not logged in" do
      before do
        visit election_path
      end

      it "does not show voting options" do
        expect(page).to have_no_content("👉 Vote on behalf of")
        expect(page).to have_no_css(".election__aside-voted")
      end
    end
  end

  context "when election uses corporate_governance_census with authorization handlers" do
    let!(:election) do
      create(
        :election,
        :published,
        :ongoing,
        component:,
        census_manifest: "corporate_governance_census",
        census_settings: {
          "setting_id" => setting.id.to_s,
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

    let!(:question) { create(:election_question, :with_response_options, :voting_enabled, election:) }

    context "when user is participant with valid authorization" do
      let(:user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }

      before do
        create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
        login_as user, scope: :user
        visit election_path
      end

      it "allows voting" do
        click_on "Vote"

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Next"
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end
    end

    context "when user is participant without authorization" do
      let(:user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }

      before do
        login_as user, scope: :user
        visit election_path
      end

      it "does not allow voting" do
        expect(page).to have_no_content("👉 Vote on behalf of")
        expect(page).to have_no_css(".election__aside-voted")
      end
    end

    context "when delegate is authorized but delegated user is not" do
      let(:user) { create(:user, :confirmed, organization:) }
      let(:delegate_user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }
      let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user) }
      let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }

      before do
        # user has no authorization
        create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata: { setting_id: setting.id })
        login_as delegate_user, scope: :user
        visit election_path
      end

      it "allows voting for themselves but not for unauthorized delegated user" do
        click_on "Vote"

        first('input[type="radio"], input[type="checkbox"]').click
        click_on "Next"
        click_on "Cast vote"

        expect(page).to have_content("Your vote has been successfully cast")
      end

      it "shows unauthorized users in delegation sidebar but prevents voting for them" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes")

        # Should show the delegated user in sidebar
        within ".election__aside-voted" do
          expect(page).to have_content(user.name.to_s)
        end
      end
    end
  end

  context "when election is per_question type with corporate_governance_census" do
    let!(:election) do
      create(
        :election,
        :published,
        :per_question,
        :ongoing,
        component:,
        census_manifest: "corporate_governance_census",
        census_settings: {
          "setting_id" => setting.id.to_s,
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

    context "when delegate votes in per-question election" do
      let(:user) { create(:user, :confirmed, organization:) }
      let(:delegate_user) { create(:user, :confirmed, organization:) }
      let!(:user_participant) { create(:participant, setting:, decidim_user: user) }
      let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user) }
      let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }

      before do
        create(:authorization, :granted, user:, name: "delegations_verifier", metadata: { setting_id: setting.id })
        create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata: { setting_id: setting.id })
        login_as delegate_user, scope: :user
        visit election_path
      end

      it "shows delegation options in sidebar for per-question elections" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes.")

        within ".election__aside-voted" do
          expect(page).to have_content(user.name.to_s)
        end
      end
    end
  end

  context "when election is not ongoing" do
    let!(:election) do
      create(
        :election,
        :published,
        :finished,
        component:,
        census_manifest: "corporate_governance_census",
        census_settings: {
          "setting_id" => setting.id.to_s
        }
      )
    end

    let(:user) { create(:user, :confirmed, organization:) }
    let(:delegate_user) { create(:user, :confirmed, organization:) }
    let!(:user_participant) { create(:participant, setting:, decidim_user: user) }
    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_user) }
    let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }

    before do
      login_as delegate_user, scope: :user
      visit election_path
    end

    it "does not show delegation options for finished election" do
      expect(page).to have_no_css(".election__aside-voted")
      expect(page).to have_no_content("You have delegated votes")
      expect(page).to have_no_link("Vote")
    end
  end
end
