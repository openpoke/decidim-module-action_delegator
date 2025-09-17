# frozen_string_literal: true

require "spec_helper"

describe "Admin manages settings" do
  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization, available_authorizations: available_authorizations) }
  let(:available_authorizations) { ["delegations_verifier"] }
  let(:user) { create(:user, :admin, :confirmed, organization:) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when listing settings" do
    let!(:setting) { create(:setting, organization:, active: true) }

    before do
      visit decidim_admin_action_delegator.settings_path
    end

    it "renders the list of settings in a table" do
      expect(page).to have_content(I18n.t("decidim.action_delegator.admin.settings.index.title"))
      expect(page).to have_content("Name")
      expect(page).to have_content("Max delegations/user")
      expect(page).to have_content("Created at")
    end

    it "shows setting information" do
      expect(page).to have_content(setting.title["en"])
      expect(page).to have_content(setting.max_grants)
      expect(page).to have_content(I18n.l(setting.created_at, format: :short))
    end

    it "has navigation links" do
      expect(page).to have_link("New configuration")
      expect(page).to have_link("Edit")
      expect(page).to have_link("Delete")
    end

    it "links to edit the setting" do
      click_on "Edit"
      expect(page).to have_current_path(decidim_admin_action_delegator.edit_setting_path(setting))
    end

    it "links to the setting's delegations" do
      click_on "Edit the delegations"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_delegations_path(setting))
    end

    it "links to the setting's participants" do
      click_on "Edit the census"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_participants_path(setting))
    end

    it "links to the setting's ponderations" do
      click_on "Set weights for vote ponderation"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_ponderations_path(setting))
    end
  end

  context "when creating settings" do
    before do
      visit decidim_admin_action_delegator.settings_path
      click_on "New configuration"
    end

    it "shows new setting form" do
      expect(page).to have_css(".new_setting")
      expect(page).to have_content("Title")
      expect(page).to have_content("Maximum vote delegations a participant can receive")
      expect(page).to have_content("Authorization method")
      expect(page).to have_button("Create")
    end

    it "creates a new setting" do
      within ".new_setting" do
        fill_in "setting_title_en", with: "Test Setting"
        fill_in :setting_max_grants, with: 5
        select "Email", from: :setting_authorization_method
        check :setting_active

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content("Test Setting")
      expect(page).to have_current_path(decidim_admin_action_delegator.settings_path)
    end

    it "validates form inputs" do
      within ".new_setting" do
        find("*[type=submit]").click
      end

      expect(page).to have_content("There is an error in this field")
    end
  end

  context "when creating with copy from other setting" do
    let!(:source_setting) { create(:setting, :with_participants, :with_ponderations, organization:, authorization_method: :both) }

    before do
      visit decidim_admin_action_delegator.settings_path
      click_on "New configuration"
    end

    it "creates a new setting with participants and ponderations from another setting" do
      fill_in "setting_title_en", with: "Copied Setting"
      fill_in :setting_max_grants, with: 3
      select "Email and phone number", from: :setting_authorization_method
      select source_setting.title["en"], from: :setting_copy_from_setting_id
      check :setting_active

      within ".new_setting" do
        click_on "Create"
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content("Copied Setting")

      new_setting = Decidim::ActionDelegator::Setting.where("title ->> 'en' = ?", "Copied Setting").first
      expect(new_setting).to be_present
      expect(new_setting.participants.count).to eq(source_setting.participants.count)
      expect(new_setting.ponderations.count).to eq(source_setting.ponderations.count)
    end
  end

  context "when editing settings" do
    let!(:setting) { create(:setting, organization:, active: true) }

    before do
      visit decidim_admin_action_delegator.settings_path
      click_on "Edit"
    end

    it "shows edit setting form" do
      expect(page).to have_content("Title")
      expect(page).to have_field("setting_title_en", with: setting.title["en"])
      expect(page).to have_field("setting_max_grants", with: setting.max_grants.to_s)
    end

    it "updates the setting" do
      fill_in "setting_title_en", with: "Updated Setting"
      fill_in :setting_max_grants, with: 10

      within ".edit_setting" do
        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content("Updated Setting")
      expect(page).to have_current_path(decidim_admin_action_delegator.settings_path)
    end

    it "validates form inputs" do
      fill_in :setting_max_grants, with: ""

      within ".edit_setting" do
        find("*[type=submit]").click
      end

      expect(page).to have_content("There is an error in this field")
    end
  end

  context "when editing settings with copy from other setting" do
    let!(:first_setting) { create(:setting, :with_participants, :with_ponderations, organization:, authorization_method: :both) }
    let!(:second_setting) { create(:setting, :with_participants, :with_ponderations, organization:, authorization_method: :both) }

    before do
      visit decidim_admin_action_delegator.settings_path
      within "tr[data-setting-id='#{first_setting.id}']" do
        click_on "Edit"
      end
    end

    it "updates a setting with copy from another setting" do
      second_setting_count = second_setting.participants.count
      first_setting_count = first_setting.participants.count

      select second_setting.title["en"], from: :setting_copy_from_setting_id

      within ".edit_setting" do
        click_on "Save"
      end

      expect(page).to have_admin_callout("successfully")
      first_setting.reload
      expect(first_setting.participants.count).to eq(first_setting_count + second_setting_count)
    end
  end

  context "when removing settings" do
    let!(:setting) { create(:setting, organization:, active: true) }

    before do
      visit decidim_admin_action_delegator.settings_path
    end

    it "removes the setting" do
      within "tr[data-setting-id='#{setting.id}']" do
        accept_confirm { click_on "Delete" }
      end

      expect(page).to have_current_path(decidim_admin_action_delegator.settings_path)
      expect(page).to have_no_content(setting.title["en"])
    end

    context "when setting is not destroyable" do
      let!(:setting_with_data) { create(:setting, :with_participants, organization:) }

      before do
        visit decidim_admin_action_delegator.settings_path
      end

      it "has no delete link" do
        within "tr[data-setting-id='#{setting_with_data.id}']" do
          expect(page).to have_no_link("Delete")
        end
      end
    end
  end

  context "when authorization method is not installed" do
    let(:available_authorizations) { [] }
    let!(:setting) { create(:setting, organization:, active: true) }

    before do
      visit decidim_admin_action_delegator.settings_path
    end

    it "shows warning about missing authorization" do
      expect(page).to have_content("authorization method is not installed")
    end
  end

  context "when setting has participants" do
    let!(:setting) { create(:setting, :with_participants, organization:, authorization_method: :email) }

    before do
      visit decidim_admin_action_delegator.settings_path
    end

    it "shows participant count" do
      expect(page).to have_content(setting.participants.count.to_s)
    end
  end

  context "when setting has different authorization methods" do
    let!(:email_setting) { create(:setting, organization:, authorization_method: :email) }
    let!(:phone_setting) { create(:setting, organization:, authorization_method: :phone) }
    let!(:both_setting) { create(:setting, organization:, authorization_method: :both) }

    before do
      visit decidim_admin_action_delegator.settings_path
    end

    it "shows different authorization methods" do
      expect(page).to have_content("Only email")
      expect(page).to have_content("Only phone number")
      expect(page).to have_content("Email and phone number")
    end
  end
end
