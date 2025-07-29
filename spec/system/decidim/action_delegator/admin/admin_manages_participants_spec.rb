# frozen_string_literal: true

require "spec_helper"

describe "Admin manages participants" do
  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization: organization) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when listing participants" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:setting) { create(:setting, consultation: consultation) }
    let!(:participant) { create(:participant, setting: setting) }

    let!(:collection) { create_list(:participant, collection_size, setting: setting) }
    let!(:resource_selector) { "[data-participant-id]" }
    let(:collection_size) { 30 }

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
    end

    it "lists 20 resources per page by default" do
      expect(page).to have_css(resource_selector, count: 20)
      expect(page).to have_css(".pagination .page", count: 2)
      # none has voted
      expect(page).to have_content("No", count: 20)
    end
  end

  context "when creating a participant" do
    let!(:consultation) { create(:consultation, organization: organization) }
    let!(:setting) { create(:setting, consultation: consultation) }

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
    end

    it "creates a new participant" do
      click_link I18n.t("participants.index.actions.new_participant", scope: i18n_scope)

      within ".new_participant" do
        fill_in :participant_email, with: "foo@example.org"
        fill_in :participant_phone, with: "12345"

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content("foo@example.org")
      expect(page).to have_content("12345")
      expect(page).to have_i18n_content(consultation.title)
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_participants_path(setting.id))
    end
  end

  context "when destroying a participant" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:question) { create(:question, consultation: consultation) }
    let(:response) { create(:response, question: question) }
    let!(:vote) { create(:vote, question: question, response: response) }
    let(:setting) { create(:setting, consultation: consultation) }
    let!(:participant) { create(:participant, setting: setting, decidim_user: user) }

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
    end

    it "destroys the participant" do
      expect(page).to have_content(participant.email)
      expect(page).to have_content(participant.phone)
      # has not voted
      expect(page).to have_content("No")
      within "tr[data-participant-id=\"#{participant.id}\"]" do
        accept_confirm { click_link "Delete" }
      end

      expect(page).to have_no_content(participant.email)
      expect(page).to have_no_content(participant.phone)
      expect(page).to have_current_path(decidim_admin_action_delegator.setting_participants_path(setting.id))
      expect(page).to have_admin_callout("successfully")
    end

    context "when participant has voted" do
      let!(:vote) { create(:vote, question: question, response: response, author: user) }

      it "does not destroy the participant" do
        expect(page).to have_content(participant.email)
        expect(page).to have_content(participant.phone)
        # has voted
        expect(page).to have_content("Yes")
        within "tr[data-participant-id=\"#{participant.id}\"]" do
          expect(page).to have_no_link("Delete")
        end
      end
    end
  end

  context "when removing census" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:question) { create(:question, consultation: consultation) }
    let(:response) { create(:response, question: question) }
    let!(:vote) { create(:vote, question: question, response: response) }
    let(:setting) { create(:setting, consultation: consultation) }
    let!(:collection) { create_list(:participant, 3, setting: setting) }

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
    end

    it "removes the census" do
      collection.each do |participant|
        expect(page).to have_content(participant.email)
      end

      accept_confirm { click_link "Remove census" }

      expect(page).to have_content("successfully")

      collection.each do |participant|
        expect(page).to have_no_content(participant.email)
      end
    end

    context "when participant has voted" do
      let!(:participant) { create(:participant, setting: setting, decidim_user: user) }
      let!(:vote) { create(:vote, question: question, response: response, author: user) }

      it "does not remove the census" do
        expect(page).to have_content(user.email)

        collection.each do |participant|
          expect(page).to have_content(participant.email)
        end

        accept_confirm { click_link "Remove census" }

        collection.each do |participant|
          expect(page).to have_no_content(participant.email)
        end

        expect(page).to have_content(user.email)
      end
    end
  end

  context "when inviting participants" do
    let(:consultation) { create(:consultation, organization: organization) }
    let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
    let(:user_exists) { create(:user, organization: organization, last_sign_in_at: 1.day.ago) }
    let(:user_with_invitation) { create(:user, organization: organization, invitation_sent_at: 1.day.ago) }
    let!(:participant_exists) { create(:participant, setting: setting, decidim_user_id: user_exists.id) }
    let!(:participant_non_exists) { create(:participant, setting: setting, decidim_user_id: nil, email: email) }
    let!(:participant_with_invitation) { create(:participant, setting: setting, decidim_user_id: user_with_invitation.id) }

    def participant_name(participant)
      participant.email.split("@").first&.gsub(/\W/, "")
    end

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
    end

    context "when authorization method is both" do
      let(:authorization_method) { "both" }
      let(:email) { "test@example.org" }

      it "has invite link for all non-exist user" do
        expect(page).to have_link(I18n.t("participants.index.send_invitation_link", scope: i18n_scope))
      end

      it "has invite link for each participant" do
        expect(page).to have_link(I18n.t("actions.invite", scope: "decidim.admin"), count: 1)
      end

      it "invites all non-existent users" do
        perform_enqueued_jobs { click_link I18n.t("participants.index.send_invitation_link", scope: i18n_scope) }

        expect(page).to have_admin_callout("successfully")

        within "tr[data-participant-id=\"#{participant_non_exists.id}\"]" do
          expect(find("td:nth-of-type(4)")).to have_content(participant_name(participant_non_exists))
        end
      end

      it "invites the one participant" do
        within "tr[data-participant-id=\"#{participant_non_exists.id}\"]" do
          click_link I18n.t("actions.invite", scope: "decidim.admin")

          expect(find("td:nth-of-type(4)")).to have_content(participant_name(participant_non_exists))
        end

        expect(page).to have_admin_callout("successfully")
      end

      context "when resend invitation" do
        it "resends invitation" do
          within "tr[data-participant-id=\"#{participant_with_invitation.id}\"]" do
            expect(page).to have_no_content(I18n.t("actions.invite", scope: "decidim.admin"))
            click_link I18n.t("actions.resend", scope: "decidim.admin")
          end

          expect(page).to have_admin_callout("successfully")
        end
      end
    end

    context "when authorization method is phone" do
      let(:authorization_method) { "phone" }
      let(:email) { "" }

      it "does not have invite link for all non-exist user" do
        expect(page).to have_no_link(I18n.t("participants.index.send_invitation_link", scope: i18n_scope))
      end

      it "does not have invite link for each participant" do
        expect(page).to have_no_link(I18n.t("actions.invite", scope: "decidim.admin"))
      end

      it "has info about authorization method" do
        expect(page).to have_content("must register themselves on the platform")
      end
    end

    context "when authorization method is email" do
      let(:authorization_method) { "email" }
      let(:email) { "test@example.org" }

      it "does not have invite link for all non-exist user" do
        expect(page).to have_link(I18n.t("participants.index.send_invitation_link", scope: i18n_scope))
      end

      it "does not have invite link for each participant" do
        expect(page).to have_link(I18n.t("actions.invite", scope: "decidim.admin"))
      end
    end

    context "when inviting users is disabled" do
      let(:authorization_method) { "both" }
      let(:email) { "test@example.org" }

      before do
        allow(Decidim::ActionDelegator).to receive(:allow_to_invite_users).and_return(false)
        visit decidim_admin_action_delegator.setting_participants_path(setting)
      end

      it "does not have invite link for all non-exist user" do
        expect(page).to have_no_link(I18n.t("participants.index.send_invitation_link", scope: i18n_scope))
      end

      it "does not have invite link for each participant" do
        expect(page).to have_no_link(I18n.t("actions.invite", scope: "decidim.admin"))
      end
    end
  end
end
