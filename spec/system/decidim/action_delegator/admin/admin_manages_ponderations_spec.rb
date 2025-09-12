# frozen_string_literal: true

require "spec_helper"

describe "Admin manages ponderations" do
  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization: organization) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when listing ponderations" do
    let(:setting) { create(:setting, organization:) }
    let!(:ponderation) { create(:ponderation, setting: setting) }
    let!(:collection) { create_list(:ponderation, collection_size, setting: setting) }
    let(:collection_size) { 50 }

    before do
      visit decidim_admin_action_delegator.setting_ponderations_path(setting)
    end

    it "lists participants with pagination" do
      within "div[data-pagination]" do
        expect(page).to have_content("Next")
      end
    end
  end

  context "when creating a ponderation" do
    let!(:setting) { create(:setting, organization:) }

    before do
      visit decidim_admin_action_delegator.setting_ponderations_path(setting)
    end

    it "creates a new ponderation" do
      click_on I18n.t("ponderations.index.actions.new_ponderation", scope: i18n_scope)

      within ".new_ponderation" do
        fill_in :ponderation_name, with: "Producer"
        fill_in :ponderation_weight, with: 2

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content("Producer")
      expect(page).to have_content("2.0")
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_ponderations_path(setting.id))
    end
  end

  context "when destroying a ponderation" do
    let(:setting) { create(:setting, organization:) }
    let!(:ponderation) { create(:ponderation, setting: setting) }
    let!(:participant) { nil }

    before do
      visit decidim_admin_action_delegator.setting_ponderations_path(setting)
    end

    it "destroys the ponderation" do
      expect(page).to have_content(ponderation.name)
      expect(page).to have_content(ponderation.weight)
      within "tr[data-ponderation-id=\"#{ponderation.id}\"]" do
        accept_confirm { click_on "Delete" }
      end

      expect(page).to have_no_content(ponderation.name)
      expect(page).to have_no_content(ponderation.weight)
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_ponderations_path(setting.id))
      expect(page).to have_admin_callout("successfully")
    end

    context "when ponderation has participants" do
      let!(:participant) { create(:participant, setting: setting, ponderation: ponderation) }

      it "does not destroy the ponderation" do
        expect(page).to have_content(ponderation.name)
        expect(page).to have_content(ponderation.weight)
        within "tr[data-ponderation-id=\"#{ponderation.id}\"]" do
          expect(page).to have_no_link("Delete")
        end
      end
    end
  end
end
