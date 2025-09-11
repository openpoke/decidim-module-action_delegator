# frozen_string_literal: true

require "spec_helper"

describe "Admin manages delegations" do
  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization:) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when listing delegations" do
    let(:setting) { create(:setting, organization:, active: true) }
    let!(:delegation) { create(:delegation, setting:) }
    let!(:collection) { create_list(:delegation, collection_size, setting:) }
    let(:collection_size) { 50 }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it "lists delegations with pagination" do
      within "div[data-pagination]" do
        expect(page).to have_content("Next")
      end
    end

    it "shows delegation information" do
      expect(page).to have_content(delegation.granter.name)
      expect(page).to have_content(delegation.grantee.name)
      expect(page).to have_content(delegation.granter.email)
      expect(page).to have_content(delegation.grantee.email)
    end

    it "shows grantee voted status" do
      expect(page).to have_content("No") # grantee_voted? returns false
    end

    it "has navigation links" do
      expect(page).to have_link("New delegation")
      expect(page).to have_link("Import via csv")
    end
  end

  context "when creating a delegation" do
    let!(:granter) { create(:user, organization:) }
    let!(:grantee) { create(:user, organization:) }
    let!(:setting) { create(:setting, organization:, active: true) }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it "shows new delegation form" do
      click_on "New delegation"

      expect(page).to have_css(".new_delegation")
      expect(page).to have_content("Granter")
      expect(page).to have_content("Grantee")
      expect(page).to have_button("Create")
    end

    it "validates form inputs" do
      click_on "New delegation"

      within ".new_delegation" do
        find("*[type=submit]").click
      end

      expect(page).to have_content("There was a problem creating the delegation")
    end
  end

  shared_examples "destroys a delegation" do
    it "destroys the delegation" do
      # has no votes (grantee_voted? = false)
      expect(page).to have_content("No")
      within "tr[data-delegation-id=\"#{delegation.id}\"]" do
        accept_confirm { click_on "Delete" }
      end

      expect(page).to have_no_content("#{delegation.grantee.name} (#{delegation.grantee.email})")
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_delegations_path(setting.id))
      expect(page).to have_admin_callout("successfully")
    end
  end

  context "when destroying a delegation" do
    let(:setting) { create(:setting, organization:, active: true) }
    let!(:delegation) { create(:delegation, setting:) }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it_behaves_like "destroys a delegation"
  end

  context "when delegation has voted" do
    let(:setting) { create(:setting, organization:, active: true) }
    let!(:delegation) { create(:delegation, setting:) }

    before do
      # Mock grantee_voted? to return true when implemented
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Decidim::ActionDelegator::Delegation).to receive(:grantee_voted?).and_return(true)
      # rubocop:enable RSpec/AnyInstance
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it "does not show delete link when grantee has voted" do
      expect(page).to have_content("Yes") # grantee voted
      within "tr[data-delegation-id=\"#{delegation.id}\"]" do
        expect(page).to have_no_link("Delete")
      end
    end
  end
end
