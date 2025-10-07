# frozen_string_literal: true

require "spec_helper"
require "decidim/action_delegator/test/delegation_examples"

describe "Delegated voting in elections", versioning: true do
  let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier dummy_authorization_handler)) }
  let(:component) { create(:elections_component, organization:) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:delegate_user) { create(:user, :confirmed, organization:) }
  let(:setting) { create(:setting, organization: component.organization, authorization_method:, active:) }
  let(:authorization_method) { :email }
  let(:active) { true }
  let!(:user_participant) { create(:participant, setting:, email: user.email) }
  let!(:delegate_participant) { create(:participant, setting:, email: delegate_user.email) }
  let!(:delegation) { create(:delegation, setting:, granter: user, grantee: delegate_user) }
  let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(election) }

  let!(:election) do
    create(
      :election,
      :published,
      :per_question,
      :ongoing,
      component:,
      census_manifest:,
      census_settings:
    )
  end
  let(:census_manifest) { "internal_users" }
  let(:census_settings) do
    {
      "authorization_handlers" => {
        "delegations_verifier" => {
          "options" => {
            "setting" => setting.id.to_s
          }
        }
      }
    }
  end

  let!(:current_question) { create(:election_question, :voting_enabled, question_type: "single_option", election:) }
  let!(:response_option1) { create(:election_response_option, question: current_question, body: { en: "Response 1" }) }
  let!(:response_option2) { create(:election_response_option, question: current_question, body: { en: "Response 2" }) }
  let!(:next_question) { create(:election_question, :with_response_options, election:) }
  let!(:authorization) { create(:authorization, :granted, user: delegate_user, name: "delegations_verifier", metadata:) }
  let(:metadata) { {} }

  before do
    switch_to_host(organization.host)
  end

  def election_per_question_vote_path(question_id, delegation_id = nil)
    path = Decidim::EngineRouter.main_proxy(component).election_per_question_vote_path(election_id: election.id, id: question_id)
    delegation_id ? "#{path}?delegation=#{delegation_id}" : path
  end

  def last_vote(voter)
    Decidim::Elections::Vote.find_by(voter_uid: voter.to_global_id.to_s)
  end

  context "when election is per_question type" do
    before do
      login_as delegate_user, scope: :user
      visit election_path
    end

    it_behaves_like "voting in a per question election"

    context "when census manifest is action_delegator_census" do
      let(:census_manifest) { "action_delegator_census" }
      let(:census_settings) do
        {
          "setting_id" => setting.id.to_s,
          "authorization_handlers" => { "delegations_verifier" => { "options" => {} } }
        }
      end

      it_behaves_like "voting in a per question election"
    end

    context "when using another verifier" do
      let(:census_manifest) { "action_delegator_census" }
      let(:census_settings) do
        {
          "setting_id" => setting.id.to_s,
          "authorization_handlers" => { "dummy_authorization_handler" => { "options" => {} } }
        }
      end

      it "does no allows to vote" do
        expect(page).to have_css(".election__aside-voted")
        expect(page).to have_content("You have delegated votes.")
        expect(page).to have_content("You can vote on behalf of the following participants in this election:")

        click_on "Vote"
        expect(page).to have_content("Verify your identity")
        expect(page).to have_content("Verify your identity\nVerify with Example authorization")
      end

      context "when authorization is granted" do
        let(:authorization) { create(:authorization, :granted, user: delegate_user, name: "dummy_authorization_handler") }

        it_behaves_like "voting in a per question election"
      end
    end
  end

  context "when election is normal (not per_question) type" do
    let!(:election) do
      create(
        :election,
        :published,
        :real_time,
        :ongoing,
        component:,
        census_manifest:,
        census_settings:
      )
    end

    context "when delegate user visits election page" do
      before do
        login_as delegate_user, scope: :user
        visit election_path
      end

      it_behaves_like "voting in a normal election"

      context "when census manifest is action_delegator_census" do
        let(:census_manifest) { "action_delegator_census" }
        let(:census_settings) do
          {
            "setting_id" => setting.id.to_s,
            "authorization_handlers" => { "delegations_verifier" => { "options" => {} } }
          }
        end

        it_behaves_like "voting in a normal election"
      end

      context "when using another verifier" do
        let(:census_manifest) { "action_delegator_census" }
        let(:census_settings) do
          {
            "setting_id" => setting.id.to_s,
            "authorization_handlers" => { "dummy_authorization_handler" => { "options" => {} } }
          }
        end

        it "does no allows to vote" do
          expect(page).to have_css(".election__aside-voted")
          expect(page).to have_content("You have delegated votes.")
          expect(page).to have_content("Vote on behalf of #{user.name}")

          click_on "Vote"
          expect(page).to have_content("Verify your identity")
          expect(page).to have_content("Verify your identity\nVerify with Example authorization")
        end

        context "when authorization is granted" do
          let(:authorization) { create(:authorization, :granted, user: delegate_user, name: "dummy_authorization_handler") }

          it_behaves_like "voting in a normal election"
        end
      end
    end
  end

  context "when user has no delegations" do
    let(:another_user) { create(:user, :confirmed, organization:) }
    let!(:delegation) { create(:delegation, setting:, granter: user, grantee: another_user) }

    before do
      login_as delegate_user, scope: :user
      visit election_path
    end

    it_behaves_like "no delegations available"
  end

  context "when election is not ongoing" do
    let!(:election) do
      create(
        :election,
        :published,
        :finished,
        component:,
        census_manifest:,
        census_settings:
      )
    end

    before do
      login_as delegate_user, scope: :user
      visit election_path
    end

    it_behaves_like "no delegations available"
  end

  context "when election results are published" do
    let!(:election) do
      create(
        :election,
        :published_results,
        component:,
        census_manifest:,
        census_settings:
      )
    end

    before do
      login_as delegate_user, scope: :user
      visit election_path
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
