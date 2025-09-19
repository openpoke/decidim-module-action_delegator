# frozen_string_literal: true

require "spec_helper"

describe "Public delegated voting results for elections" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let!(:component) { create(:elections_component, :published, organization:) }
  let(:setting) { create(:setting, organization:) }

  let!(:ponderation_basic) { create(:ponderation, setting:, name: "Basic Member", weight: 1.0) }
  let!(:ponderation_premium) { create(:ponderation, setting:, name: "Premium Member", weight: 3.0) }
  let!(:ponderation_vip) { create(:ponderation, setting:, name: "VIP Member", weight: 5.0) }

  def election_path(election_instance)
    Decidim::EngineRouter.main_proxy(component).election_path(election_instance)
  end

  def create_election_with_action_delegator(availability_trait: :real_time)
    create(
      :election,
      :published,
      :ongoing,
      availability_trait,
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

  before do
    switch_to_host(organization.host)
  end

  context "with real-time results and weighted direct votes" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }
    let(:option_a) { question.response_options.first }
    let(:option_b) { question.response_options.second }

    let!(:basic_user) { create(:user, :confirmed, organization:) }
    let!(:premium_user) { create(:user, :confirmed, organization:) }
    let!(:vip_user) { create(:user, :confirmed, organization:) }

    let!(:basic_participant) { create(:participant, setting:, decidim_user: basic_user, ponderation: ponderation_basic) }
    let!(:premium_participant) { create(:participant, setting:, decidim_user: premium_user, ponderation: ponderation_premium) }
    let!(:vip_participant) { create(:participant, setting:, decidim_user: vip_user, ponderation: ponderation_vip) }

    let!(:basic_authorization) { create(:authorization, :granted, user: basic_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:premium_authorization) { create(:authorization, :granted, user: premium_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:vip_authorization) { create(:authorization, :granted, user: vip_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:basic_vote) { create(:election_vote, question:, response_option: option_a, voter_uid: basic_user.to_global_id.to_s) }
    let!(:premium_vote) { create(:election_vote, question:, response_option: option_a, voter_uid: premium_user.to_global_id.to_s) }
    let!(:vip_vote) { create(:election_vote, question:, response_option: option_b, voter_uid: vip_user.to_global_id.to_s) }

    before do
      visit election_path(election)
    end

    it "shows weighted results interface" do
      expect(page).to have_css("[data-weight-results-live-update]")
      expect(page.html).to include("decidim_action_delegator_elections")
    end

    it "calculates weighted vote counts correctly" do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("4") # basic (1.0) + premium (3.0) = 4.0
          expect(page).to have_content("44.4%") # 4/9 = 44.4%
          expect(page).to have_content("5") # vip (5.0)
          expect(page).to have_content("55.6%") # 5/9 = 55.6%
        end
      end
    end
  end

  context "with delegated votes using granter's weight" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }
    let(:option_a) { question.response_options.first }
    let(:option_b) { question.response_options.second }

    let!(:granter_premium) { create(:user, :confirmed, organization:) }
    let!(:delegate_basic) { create(:user, :confirmed, organization:) }
    let!(:direct_voter) { create(:user, :confirmed, organization:) }

    let!(:granter_participant) { create(:participant, setting:, decidim_user: granter_premium, ponderation: ponderation_premium) }
    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_basic, ponderation: ponderation_basic) }
    let!(:direct_participant) { create(:participant, setting:, decidim_user: direct_voter, ponderation: ponderation_basic) }

    let!(:granter_authorization) { create(:authorization, :granted, user: granter_premium, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:delegate_authorization) { create(:authorization, :granted, user: delegate_basic, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:direct_authorization) { create(:authorization, :granted, user: direct_voter, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: granter_premium, grantee: delegate_basic) }

    let!(:direct_vote) { create(:election_vote, question:, response_option: option_a, voter_uid: direct_voter.to_global_id.to_s) }
    let!(:delegated_vote) { create(:election_vote, question:, response_option: option_b, voter_uid: granter_premium.to_global_id.to_s) }

    before do
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: delegate_basic.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      visit election_path(election)
    end

    it "applies granter's weight to delegated votes" do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("1") # direct basic vote (1.0)
          expect(page).to have_content("25.0%") # 1/4 = 25%
          expect(page).to have_content("3") # delegated vote uses granter's premium weight (3.0)
          expect(page).to have_content("75.0%") # 3/4 = 75%
        end
      end
    end
  end

  context "with mixed direct and delegated votes" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }
    let(:option_a) { question.response_options.first }
    let(:option_b) { question.response_options.second }

    let!(:delegate_premium) { create(:user, :confirmed, organization:) }
    let!(:granter_vip) { create(:user, :confirmed, organization:) }

    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_premium, ponderation: ponderation_premium) }
    let!(:granter_participant) { create(:participant, setting:, decidim_user: granter_vip, ponderation: ponderation_vip) }

    let!(:delegate_authorization) { create(:authorization, :granted, user: delegate_premium, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:granter_authorization) { create(:authorization, :granted, user: granter_vip, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: granter_vip, grantee: delegate_premium) }

    let!(:delegate_own_vote) { create(:election_vote, question:, response_option: option_a, voter_uid: delegate_premium.to_global_id.to_s) }
    let!(:delegated_vote) { create(:election_vote, question:, response_option: option_b, voter_uid: granter_vip.to_global_id.to_s) }

    before do
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: delegate_premium.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      visit election_path(election)
    end

    it "calculates weights correctly for both direct and delegated votes" do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("3") # delegate's direct vote (3.0)
          expect(page).to have_content("37.5%") # 3/8 = 37.5%
          expect(page).to have_content("5") # delegated vote uses granter's VIP weight (5.0)
          expect(page).to have_content("62.5%") # 5/8 = 62.5%
        end
      end
    end
  end

  context "with users without explicit ponderation" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }
    let(:option_a) { question.response_options.first }
    let(:option_b) { question.response_options.second }

    let!(:user_with_weight) { create(:user, :confirmed, organization:) }
    let!(:user_without_weight) { create(:user, :confirmed, organization:) }

    let!(:participant_with_weight) { create(:participant, setting:, decidim_user: user_with_weight, ponderation: ponderation_premium) }
    let!(:participant_without_weight) { create(:participant, setting:, decidim_user: user_without_weight, ponderation: nil) }

    let!(:authorization_with_weight) { create(:authorization, :granted, user: user_with_weight, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:authorization_without_weight) { create(:authorization, :granted, user: user_without_weight, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:vote_with_weight) { create(:election_vote, question:, response_option: option_a, voter_uid: user_with_weight.to_global_id.to_s) }
    let!(:vote_without_weight) { create(:election_vote, question:, response_option: option_a, voter_uid: user_without_weight.to_global_id.to_s) }

    before do
      visit election_path(election)
    end

    it "gives default weight 1.0 to participants without ponderation" do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("4") # premium (3.0) + default (1.0) = 4.0
          expect(page).to have_content("100.0%")
        end
      end
    end
  end

  context "with delegated votes from users without ponderation" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }
    let(:option_a) { question.response_options.first }
    let(:option_b) { question.response_options.second }

    let!(:granter_no_weight) { create(:user, :confirmed, organization:) }
    let!(:delegate_basic) { create(:user, :confirmed, organization:) }
    let!(:direct_premium) { create(:user, :confirmed, organization:) }

    let!(:granter_participant) { create(:participant, setting:, decidim_user: granter_no_weight, ponderation: nil) }
    let!(:delegate_participant) { create(:participant, setting:, decidim_user: delegate_basic, ponderation: ponderation_basic) }
    let!(:direct_participant) { create(:participant, setting:, decidim_user: direct_premium, ponderation: ponderation_premium) }

    let!(:granter_authorization) { create(:authorization, :granted, user: granter_no_weight, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:delegate_authorization) { create(:authorization, :granted, user: delegate_basic, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:direct_authorization) { create(:authorization, :granted, user: direct_premium, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: granter_no_weight, grantee: delegate_basic) }

    let!(:delegated_vote) { create(:election_vote, question:, response_option: option_a, voter_uid: granter_no_weight.to_global_id.to_s) }
    let!(:direct_vote) { create(:election_vote, question:, response_option: option_b, voter_uid: direct_premium.to_global_id.to_s) }

    before do
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: delegate_basic.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      visit election_path(election)
    end

    it "uses default weight 1.0 for granter without ponderation" do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("1") # delegated vote uses granter's default weight (1.0)
          expect(page).to have_content("25.0%") # 1/4 = 25%
          expect(page).to have_content("3") # direct premium vote (3.0)
          expect(page).to have_content("75.0%") # 3/4 = 75%
        end
      end
    end
  end

  context "with per-question results availability" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :per_question) }
    let!(:published_question) { create(:election_question, :with_response_options, :voting_enabled, election:) }
    let!(:unpublished_question) { create(:election_question, :with_response_options, election:) }

    let!(:basic_user) { create(:user, :confirmed, organization:) }
    let!(:premium_user) { create(:user, :confirmed, organization:) }

    let!(:basic_participant) { create(:participant, setting:, decidim_user: basic_user, ponderation: ponderation_basic) }
    let!(:premium_participant) { create(:participant, setting:, decidim_user: premium_user, ponderation: ponderation_premium) }

    let!(:basic_authorization) { create(:authorization, :granted, user: basic_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:premium_authorization) { create(:authorization, :granted, user: premium_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: premium_user, grantee: basic_user) }

    let!(:published_vote) { create(:election_vote, question: published_question, response_option: published_question.response_options.first, voter_uid: basic_user.to_global_id.to_s) }
    let!(:delegated_vote) { create(:election_vote, question: published_question, response_option: published_question.response_options.second, voter_uid: premium_user.to_global_id.to_s) }

    before do
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: basic_user.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      published_question.update!(published_results_at: Time.current)
      visit election_path(election)
    end

    it "shows results only for published questions" do
      within "#question-#{published_question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("1") # basic direct vote (1.0)
          expect(page).to have_content("3") # delegated vote uses granter's premium weight (3.0)
        end
      end

      expect(page).to have_no_css("#question-#{unpublished_question.id}")
    end
  end

  context "with after-end results availability" do
    let!(:election) { create_election_with_action_delegator(availability_trait: :after_end) }
    let(:question) { election.questions.first }

    let!(:basic_user) { create(:user, :confirmed, organization:) }
    let!(:premium_user) { create(:user, :confirmed, organization:) }

    let!(:basic_participant) { create(:participant, setting:, decidim_user: basic_user, ponderation: ponderation_basic) }
    let!(:premium_participant) { create(:participant, setting:, decidim_user: premium_user, ponderation: ponderation_premium) }

    let!(:basic_authorization) { create(:authorization, :granted, user: basic_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:premium_authorization) { create(:authorization, :granted, user: premium_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: premium_user, grantee: basic_user) }

    let!(:delegated_vote) { create(:election_vote, question:, response_option: question.response_options.first, voter_uid: premium_user.to_global_id.to_s) }

    before do
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: basic_user.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      visit election_path(election)
    end

    it "hides results while election is ongoing" do
      expect(page).to have_no_css("[data-weight-results-live-update]")
      expect(page).to have_no_content("vote")
    end

    context "when results are manually published" do
      before do
        election.update!(published_results_at: Time.current)
        visit election_path(election)
      end

      it "shows weighted results after publication" do
        expect(page).to have_css("[data-weight-results-live-update]")
        within "#question-#{question.id}" do
          within ".card-accordion-section" do
            expect(page).to have_content("3") # delegated vote uses granter's premium weight (3.0)
            expect(page).to have_content("100.0%")
          end
        end
      end
    end
  end

  context "with live JavaScript updates", :js do
    let!(:election) { create_election_with_action_delegator(availability_trait: :real_time) }
    let(:question) { election.questions.first }

    let!(:basic_user) { create(:user, :confirmed, organization:) }
    let!(:premium_user) { create(:user, :confirmed, organization:) }

    let!(:basic_participant) { create(:participant, setting:, decidim_user: basic_user, ponderation: ponderation_basic) }
    let!(:premium_participant) { create(:participant, setting:, decidim_user: premium_user, ponderation: ponderation_premium) }

    let!(:basic_authorization) { create(:authorization, :granted, user: basic_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }
    let!(:premium_authorization) { create(:authorization, :granted, user: premium_user, name: "delegations_verifier", metadata: { setting_id: setting.id }) }

    let!(:delegation) { create(:delegation, setting:, granter: premium_user, grantee: basic_user) }

    let!(:initial_vote) { create(:election_vote, question:, response_option: question.response_options.first, voter_uid: basic_user.to_global_id.to_s) }

    before do
      visit election_path(election)
    end

    it "updates results when delegated votes are added", :slow do
      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("1") # initial basic vote
          expect(page).to have_content("100.0%")
        end
      end

      delegated_vote = create(:election_vote, question:, response_option: question.response_options.second, voter_uid: premium_user.to_global_id.to_s)
      delegated_vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: delegated_vote.id,
        event: "create",
        whodunnit: basic_user.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      sleep 5

      within "#question-#{question.id}" do
        within ".card-accordion-section" do
          expect(page).to have_content("25.0%") # 1/4 = 25%
          expect(page).to have_content("75.0%") # 3/4 = 75%
        end
      end
    end
  end

  context "without Action Delegator settings" do
    let!(:normal_election) do
      create(
        :election,
        :published,
        :ongoing,
        :real_time,
        :with_questions,
        component:,
        census_manifest: "internal_users"
      )
    end

    before do
      visit election_path(normal_election)
    end

    it "does not include Action Delegator weighted results functionality" do
      expect(page).to have_no_css("[data-weight-results-live-update]")
      expect(page.html).not_to include("decidim_action_delegator_elections")
    end

    it "shows standard Decidim election interface" do
      expect(page).to have_content(translated(normal_election.title))
      expect(page).to have_css("#question-#{normal_election.questions.first.id}")
    end
  end
end
