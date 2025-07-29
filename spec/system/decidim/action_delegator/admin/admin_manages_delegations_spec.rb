# frozen_string_literal: true

require "spec_helper"

describe "Admin manages delegations" do
  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization: organization) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when listing delegations" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:setting) { create(:setting, consultation: consultation) }
    let!(:delegation) { create(:delegation, setting: setting) }

    let!(:collection) { create_list(:delegation, collection_size, setting: setting) }
    let!(:resource_selector) { "[data-delegation-id]" }
    let(:collection_size) { 30 }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it "lists 20 resources per page by default" do
      expect(page).to have_css(resource_selector, count: 20)
      expect(page).to have_css(".pagination .page", count: 2)
    end
  end

  context "when creating a delegation" do
    let!(:granter) { create(:user, organization: organization) }
    let!(:grantee) { create(:user, organization: organization) }
    let!(:consultation) { create(:consultation, organization: organization) }
    let!(:setting) { create(:setting, consultation: consultation) }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it "creates a new delegation" do
      click_link I18n.t("delegations.index.actions.new_delegation", scope: i18n_scope)

      within ".new_delegation" do
        custom_autocomplete_select "#{granter.name} (@#{granter.nickname})", from: :granter_id
        custom_autocomplete_select "#{grantee.name} (@#{grantee.nickname})", from: :grantee_id

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content(grantee.name)
      expect(page).to have_i18n_content(consultation.title)
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_delegations_path(setting.id))
    end
  end

  shared_examples "destroys a delegation" do
    it "destroys the delegation" do
      # has no votes
      expect(page).to have_content("No")
      expect(page).to have_no_content("Yes")
      within "tr[data-delegation-id=\"#{delegation.id}\"]" do
        accept_confirm { click_link "Delete" }
      end

      expect(page).to have_no_content(delegation.grantee.name)
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_delegations_path(setting.id))
      expect(page).to have_admin_callout("successfully")
    end
  end

  shared_examples "do not destroy a delegation" do
    it "does not destroy the delegation" do
      # has votes
      expect(page).to have_no_content("No")
      expect(page).to have_content("Yes")
      within "tr[data-delegation-id=\"#{delegation.id}\"]" do
        expect(page).to have_no_link("Delete")
      end
    end
  end

  context "when destroying a delegation" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:question) { create(:question, consultation: consultation) }
    let(:response) { create(:response, question: question) }
    let!(:vote) { create(:vote, response: response, question: question) }
    let(:setting) { create(:setting, consultation: consultation) }
    let!(:delegation) { create(:delegation, setting: setting) }

    before do
      visit decidim_admin_action_delegator.setting_delegations_path(setting)
    end

    it_behaves_like "destroys a delegation"

    context "and granter has voted", versioning: true do
      let!(:vote) { create(:vote, response: response, question: question, author: delegation.granter) }

      it_behaves_like "destroys a delegation"
    end

    context "and grantee has voted in behalf of the granter" do
      let!(:vote) { create(:vote, response: response, question: question, author: delegation.granter) }

      before do
        PaperTrail::Version.create!(
          item_type: "Decidim::Consultations::Vote",
          item_id: vote.id,
          event: "create",
          whodunnit: delegation.grantee.id,
          decidim_action_delegator_delegation_id: delegation.id
        )
        visit decidim_admin_action_delegator.setting_delegations_path(setting)
      end

      it_behaves_like "do not destroy a delegation"
    end
  end
end
