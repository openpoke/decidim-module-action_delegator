# frozen_string_literal: true

require "spec_helper"

describe "User delegations page" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:granter) { create(:user, :confirmed, organization:) }
  let(:setting) { create(:setting, organization:) }
  let!(:delegation) { create(:delegation, setting:, granter:, grantee: user) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit decidim_action_delegator.user_delegations_path
  end

  context "when the setting has an active election" do
    let(:component) { create(:elections_component, organization:) }
    let!(:election) do
      create(
        :election,
        :published,
        :ongoing,
        component:,
        census_manifest: "action_delegator_census",
        census_settings: { "setting_id" => setting.id.to_s, "authorization_handlers" => {} }
      )
    end

    before do
      visit decidim_action_delegator.user_delegations_path
    end

    it "shows a link to vote and the granter's name" do
      expect(page).to have_link(
        translated_attribute(election.title),
        href: Decidim::EngineRouter.main_proxy(component).election_path(election)
      )
      expect(page).to have_content(granter.name)
    end
  end

  context "when there are no active elections for the delegation" do
    it "shows a placeholder message" do
      expect(page).to have_content("no active delegated votes")
    end
  end
end
