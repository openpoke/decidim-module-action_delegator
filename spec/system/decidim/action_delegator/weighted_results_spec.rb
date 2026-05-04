# frozen_string_literal: true

require "spec_helper"

describe "Weighted election results" do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, organization:) }
  let(:setting) { create(:setting, organization:) }

  let!(:ponderation_low) { create(:ponderation, setting:, name: "Low Weight", weight: 1.0) }
  let!(:ponderation_high) { create(:ponderation, setting:, name: "High Weight", weight: 3.0) }

  let!(:election) do
    create(
      :election,
      :published,
      :published_results,
      :real_time,
      component:,
      census_manifest: "internal_users",
      census_settings: {
        "authorization_handlers" => {
          "delegations_verifier" => { "options" => { "setting" => setting.id.to_s } }
        }
      }
    )
  end

  let!(:question) { create(:election_question, :with_response_options, :voting_enabled, skip_injection: true, election:, question_type: "single_option") }
  let(:option1) { question.response_options.first }
  let(:option2) { question.response_options.second }

  let(:election_path) { Decidim::EngineRouter.main_proxy(component).election_path(election) }

  before { switch_to_host(organization.host) }

  def vote_count_for(option)
    find("[data-option-votes-count-text='#{question.id},#{option.id}']")
  end

  def vote_percent_for(option)
    find("[data-option-votes-percent-text='#{question.id},#{option.id}']")
  end

  context "when users with different ponderations vote" do
    let!(:user_low_first) { create(:user, :confirmed, organization:) }
    let!(:user_low_second) { create(:user, :confirmed, organization:) }
    let!(:user_high_first) { create(:user, :confirmed, organization:) }
    let!(:user_high_second) { create(:user, :confirmed, organization:) }

    let!(:participant_low_first) { create(:participant, setting:, decidim_user: user_low_first, ponderation: ponderation_low) }
    let!(:participant_low_second) { create(:participant, setting:, decidim_user: user_low_second, ponderation: ponderation_low) }
    let!(:participant_high_first) { create(:participant, setting:, decidim_user: user_high_first, ponderation: ponderation_high) }
    let!(:participant_high_second) { create(:participant, setting:, decidim_user: user_high_second, ponderation: ponderation_high) }

    before do
      create(:election_vote, question:, response_option: option1, voter_uid: user_low_first.to_global_id.to_s)
      create(:election_vote, question:, response_option: option1, voter_uid: user_low_second.to_global_id.to_s)
      create(:election_vote, question:, response_option: option2, voter_uid: user_high_first.to_global_id.to_s)
      create(:election_vote, question:, response_option: option2, voter_uid: user_high_second.to_global_id.to_s)

      visit election_path
    end

    it "shows weighted totals and percentages" do
      within "#question-#{question.id}" do
        expect(vote_count_for(option1)).to have_content("2")
        expect(vote_percent_for(option1)).to have_content("25.0%")

        expect(vote_count_for(option2)).to have_content("6")
        expect(vote_percent_for(option2)).to have_content("75.0%")
      end
    end
  end

  context "when a delegated vote is cast" do
    let!(:granter) { create(:user, :confirmed, organization:) }
    let!(:grantee) { create(:user, :confirmed, organization:) }

    let!(:granter_participant) { create(:participant, setting:, decidim_user: granter, ponderation: ponderation_high) }
    let!(:grantee_participant) { create(:participant, setting:, decidim_user: grantee, ponderation: ponderation_low) }

    let!(:delegation) { create(:delegation, setting:, granter:, grantee:) }

    before do
      vote = create(:election_vote, question:, response_option: option1, voter_uid: granter.to_global_id.to_s)
      vote.versions.create!(
        item_type: "Decidim::Elections::Vote",
        item_id: vote.id,
        event: "create",
        whodunnit: grantee.id.to_s,
        decidim_action_delegator_delegation_id: delegation.id
      )

      visit election_path
    end

    it "uses the granter's ponderation, not the grantee's" do
      within "#question-#{question.id}" do
        expect(vote_count_for(option1)).to have_content("3")
      end
    end
  end

  context "when a user without participant ponderation votes" do
    let!(:user_no_participant) { create(:user, :confirmed, organization:) }

    before do
      create(:election_vote, question:, response_option: option1, voter_uid: user_no_participant.to_global_id.to_s)

      visit election_path
    end

    it "applies the default weight of 1.0" do
      within "#question-#{question.id}" do
        expect(vote_count_for(option1)).to have_content("1")
      end
    end
  end
end
