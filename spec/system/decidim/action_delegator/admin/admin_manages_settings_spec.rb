# frozen_string_literal: true

require "spec_helper"

describe "Admin manages settings" do
  include Decidim::TranslationsHelper

  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization, available_authorizations: available_authorizations) }
  let(:available_authorizations) { ["delegations_verifier"] }
  let!(:consultation) { create(:consultation, organization: organization) }
  let!(:questions) { create_list(:question, 2, consultation: consultation) }
  let!(:authorization) { create(:authorization, user: another_user, name: "delegations_verifier", granted_at: Time.current) }
  let!(:user) { create(:user, :admin, :confirmed, organization: organization, email: "bar@example.org") }
  let!(:another_user) { create(:user, :confirmed, organization: organization) }
  let(:permissions) do
    questions.index_with { |_question| { "vote" => { "authorization_handlers" => { "delegations_verifier" => {} } } } }.to_h
  end

  context "when creating settings" do
    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin.users_path
      click_link I18n.t("decidim.action_delegator.admin.menu.delegations")

      click_link I18n.t("decidim.action_delegator.admin.settings.index.actions.new_setting")
    end

    it "creates a new setting" do
      within ".new_setting" do
        fill_in :setting_max_grants, with: 5
        select translated_attribute(consultation.title), from: :setting_decidim_consultation_id

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content(translated_attribute(consultation.title))
      expect(page).to have_current_path(decidim_admin_action_delegator.settings_path)
    end
  end

  context "when creating with copy from other setting" do
    let!(:first_consultation) { create(:consultation, organization: organization) }
    let!(:setting) { create(:setting, :with_participants, :with_ponderations, authorization_method: :both, consultation: first_consultation) }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin.users_path
      click_link I18n.t("decidim.action_delegator.admin.menu.delegations")

      click_link I18n.t("decidim.action_delegator.admin.settings.index.actions.new_setting")
    end

    it "creates a new setting with participants and ponderations from an other setting" do
      fill_in :setting_max_grants, with: 5
      select translated_attribute(consultation.title), from: :setting_decidim_consultation_id
      select translated_attribute(first_consultation.title), from: :setting_copy_from_setting_id

      find("*[type=submit]").click

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content(translated_attribute(first_consultation.title))
      expect(page).to have_css("tr[data-setting-id='#{setting.id}'] td:nth-of-type(5)", text: "3")
      expect(page).to have_css("tr[data-setting-id='#{setting.id}'] td:nth-of-type(6)", text: "3")

      row_with_new_setting = find(:xpath, "//table/tbody/tr[1]")
      row_with_new_setting.find(:link, I18n.t("decidim.action_delegator.admin.settings.index.actions.census")).click

      # Check that the participants from the copied setting are present
      setting.participants.each do |participant|
        expect(page).to have_content(participant.email)
      end
    end
  end

  context "when editing settings with copy from other setting" do
    let!(:first_consultation) { create(:consultation, organization: organization) }
    let!(:first_setting) { create(:setting, :with_participants, :with_ponderations, authorization_method: :both, consultation: first_consultation) }
    let!(:second_setting) { create(:setting, :with_participants, :with_ponderations, authorization_method: :both, consultation: consultation) }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin.users_path
      click_link I18n.t("decidim.action_delegator.admin.menu.delegations")

      find("tr[data-setting-id='#{first_setting.id}'] a.action-icon--edit[title='Edit']").click
    end

    it "edits a setting" do
      select translated_attribute(consultation.title), from: :setting_copy_from_setting_id

      find("*[type=submit]").click

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content(translated_attribute(first_consultation.title))
      expect(page).to have_css("tr[data-setting-id='#{first_setting.id}'] td:nth-of-type(5)", text: "6")
      expect(page).to have_css("tr[data-setting-id='#{first_setting.id}'] td:nth-of-type(6)", text: "6")

      edited_setting_row = find("tr[data-setting-id='#{first_setting.id}']")
      edited_setting_row.find("a[title='#{I18n.t("decidim.action_delegator.admin.settings.index.actions.census")}']").click

      # Check that the participants from the other setting are on the list
      second_setting.participants.each do |participant|
        expect(page).to have_content(participant.email)
      end

      # Check that the participants from the edited setting are on the list
      first_setting.participants.each do |participant|
        expect(page).to have_content(participant.email)
      end
    end
  end

  context "when listing settings" do
    let(:participants) { [] }
    let(:authorization_method) { :both }
    let!(:setting) { create(:setting, consultation: consultation, participants: participants, authorization_method: authorization_method) }

    before do
      permissions.each { |question, permission| question.build_resource_permission.update!(permissions: permission) }
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin.users_path
      click_link I18n.t("decidim.action_delegator.admin.menu.delegations")
    end

    it "renders the list of settings in a table" do
      expect(page).to have_no_content('"Delegation Verifier" authorization method is not installed')
      expect(page).to have_content(I18n.t("decidim.action_delegator.admin.settings.index.title"))

      expect(page).to have_content(I18n.t("settings.index.consultation", scope: i18n_scope))
      expect(page).to have_content(I18n.t("settings.index.created_at", scope: i18n_scope))

      expect(page).to have_content(translated_attribute(consultation.title))
      expect(page).to have_content(I18n.l(setting.created_at, format: :short))
    end

    it "links to the consultation" do
      expect(page).to have_xpath(
        "//a[@href='#{decidim_consultations.consultation_path(consultation)}'][@target='blank']"
      )
    end

    it "links to edit the setting" do
      click_link "Edit"
      expect(page).to have_current_path(decidim_admin_action_delegator.edit_setting_path(setting))
    end

    it "links to the setting's delegations" do
      click_link "Edit the delegations"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_delegations_path(setting))
    end

    it "links to the setting's participants" do
      click_link "Edit the census"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_participants_path(setting))
    end

    it "links to the setting's ponderations" do
      click_link "Set weights for vote ponderation"
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_ponderations_path(setting))
    end

    it "shows a callout with information" do
      expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
      expect(page).to have_content("There is no census! Add participants or nobody will be able to vote if Corporate Governance Verifier is active")
    end

    context "when there are participants" do
      let(:email) { "foo@example.org" }
      let(:phone) { "123456789" }
      let(:participants) { [build(:participant, email: email, phone: phone)] }
      let(:seed) { "something" }
      let(:uniq_id) { Digest::MD5.hexdigest("#{seed}-#{organization.id}-#{Digest::MD5.hexdigest(Rails.application.secret_key_base)}") }

      it "complains about registration" do
        expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
        expect(page).to have_content("There are 1 participants that are not registered into the platform")
        expect(page).to have_content("There are 1 participants that are not verified by the Corporate Governance Verifier")
        expect(page).to have_css(".callout.warning")
      end

      context "when participants are registered" do
        let(:email) { user.email }

        it "complains about verification" do
          expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
          expect(page).to have_content("All participants are registered into the platform")
          expect(page).to have_content("There are 1 participants that are not verified by the Corporate Governance Verifier")
          expect(page).to have_css(".callout.warning")
        end

        context "when participants are verified" do
          let!(:authorization) { create(:authorization, user: user, name: "delegations_verifier", unique_id: uniq_id, granted_at: Time.current) }

          it "is happy" do
            expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
            expect(page).to have_content("All participants are registered into the platform")
            expect(page).to have_content("All participants are verified by the Corporate Governance Verifier")
            expect(page).to have_css(".callout.success")
          end

          context "and unque_id is by email" do
            let(:seed) { phone }
            let(:email) { "another@email" }

            it "is happy" do
              expect(page).to have_content("All participants are verified by the Corporate Governance Verifier")
            end
          end
        end
      end

      context "when participants are not synced" do
        let(:email) { user.email }

        before do
          participants.first.update_column(:decidim_user_id, nil) # rubocop:disable Rails/SkipsModelValidations:
          click_link I18n.t("decidim.action_delegator.admin.menu.delegations")
        end

        it "is alert" do
          expect(page).to have_content("The participants list needs to be synchronized")
          expect(page).to have_link(href: decidim_admin_action_delegator.sync_setting_permissions_path(setting))
          expect(page).to have_css(".callout.alert")

          perform_enqueued_jobs { click_link "Click here to automatically fix this" }

          expect(page).to have_no_css(".callout.alert")
          expect(page).to have_no_content("The participants list needs to be synchronized")
        end

        context "and participants are not registered" do
          let(:email) { "foo@example.org" }

          it "has no alert" do
            expect(page).to have_no_css(".callout.alert")
            expect(page).to have_no_content("The participants list needs to be synchronized")
          end
        end
      end
    end

    context "when verifier is not installed" do
      let(:available_authorizations) { [] }

      it "alerts with a message" do
        expect(page).to have_content('"Corporate Governance Verifier" authorization method is not installed')
      end
    end

    context "when all questions are unrestricted" do
      let(:permissions) { {} }

      it "has a link to fix it" do
        expect(page).to have_no_content('"Delegation Verifier" authorization method is not installed')
        expect(page).to have_content("There are 2 questions that are not restricted by the Corporate Governance Verifier.")
        expect(page).to have_no_content("All questions are restricted by the Corporate Governance Verifier")
        expect(page).to have_css(".callout.success")

        click_link "Click here to automatically fix this"

        expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
      end
    end

    context "when some questions are unrestricted" do
      let(:permissions) do
        { questions.first => { "vote" => { "authorization_handlers" => { "delegations_verifier" => {} } } } }
      end

      it "has a link to fix it" do
        expect(page).to have_no_content('"Corporate Governance Verifier" authorization method is not installed')
        expect(page).to have_content("There are 1 questions that are not restricted by the Corporate Governance Verifier.")
        expect(page).to have_no_content("All questions are restricted by the Corporate Governance Verifier")
        expect(page).to have_css(".callout.warning")

        click_link "Click here to automatically fix this"

        expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
      end
    end

    context "when some questions have other permissions" do
      let(:permissions) do
        {
          questions.first => { "vote" => { "authorization_handlers" => { "delegations_verifier" => {} } } },
          questions.second => { "vote" => { "authorization_handlers" => { "another_verifier" => {} } } }
        }
      end

      it "has a link to fix it" do
        expect(page).to have_no_content('"Corporate Governance Verifier" authorization method is not installed')
        expect(page).to have_content("There are 1 questions that are not restricted by the Corporate Governance Verifier.")
        expect(page).to have_no_content("All questions are restricted by the Corporate Governance Verifier")
        expect(page).to have_css(".callout.warning")

        click_link "Click here to automatically fix this"

        expect(page).to have_content("All questions are restricted by the Corporate Governance Verifier")
      end
    end
  end

  context "when removing settings" do
    let!(:delegation) { nil }
    let!(:setting) { create(:setting, consultation: consultation) }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin.users_path
      click_link I18n.t("decidim.action_delegator.admin.menu.delegations")
    end

    it "removes the setting" do
      within "tr[data-setting-id=\"#{setting.id}\"]" do
        accept_confirm { click_link "Delete" }
      end

      expect(page).to have_current_path(decidim_admin_action_delegator.settings_path)
      expect(page).to have_no_content(translated_attribute(consultation.title))
    end

    context "when setting is not destroyable" do
      let!(:delegation) { create(:delegation, setting: setting) }

      it "has no delete link" do
        within "tr[data-setting-id=\"#{setting.id}\"]" do
          expect(page).to have_no_link("Delete")
        end
      end
    end
  end
end
