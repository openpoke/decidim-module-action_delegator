# frozen_string_literal: true

require "spec_helper"

describe "Census Configuration", :slow do
  let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
  let(:component) { create(:elections_component, organization:) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let!(:election) { create(:election, component:, census_manifest: "internal_users") }
  let(:census_path) { Decidim::EngineRouter.admin_proxy(component).election_census_path(election) }

  before do
    switch_to_host(organization.host)
    login_as admin_user, scope: :user
  end

  context "when configuring census" do
    let!(:setting) { create(:setting, organization:, active: true, title: { "en" => "Test Setting" }) }
    let!(:setting2) { create(:setting, organization:, active: true, title: { "en" => "Another Setting" }) }

    before do
      visit census_path
    end

    it "shows census manifest selector" do
      expect(page).to have_select("census_manifest", with_options: ["Registered participants (dynamic)", "Corporate governance census"])
    end

    context "when corporate governance census is selected" do
      before do
        select "Corporate governance census", from: "census_manifest"
        sleep 1
      end

      it "shows setting selector" do
        expect(page).to have_select("corporate_governance_census[setting_id]", with_options: ["Test Setting", "Another Setting"])
      end

      it "shows authorization handlers section and setting selector" do
        expect(page).to have_content("Additional required authorizations to vote")
        expect(page).to have_content("Corporate Governance")
        expect(page).to have_select("corporate_governance_census[setting_id]")
      end

      context "when setting is selected" do
        let!(:user1) { create(:user, :confirmed, organization:, email: "corp_user1@example.org") }
        let!(:user2) { create(:user, :confirmed, organization:, email: "corp_user2@example.org") }
        let!(:participant1) { create(:participant, setting:, decidim_user: user1, email: "corp_user1@example.org") }
        let!(:participant2) { create(:participant, setting:, decidim_user: user2, email: "corp_user2@example.org") }
        let!(:delegation1) { create(:delegation, setting:, granter: user1, grantee: user2) }
        let!(:delegation2) { create(:delegation, setting:, granter: user2, grantee: user1) }

        before do
          select "Test Setting", from: "corporate_governance_census[setting_id]"
          click_button "Save and continue"
        end

        it "shows all organization users count when no authorization handlers are required (enables delegations for all users)" do
          visit census_path
          expect(page).to have_content("There are currently 3 people eligible for voting")
        end

        it "allows saving configuration" do
          expect(page).to have_content("updated successfully")
        end

        context "when authorization handlers are required" do
          let!(:auth1) { create(:authorization, user: user1, name: "delegations_verifier", granted_at: Time.current) }
          let!(:auth2) { create(:authorization, user: user2, name: "delegations_verifier", granted_at: Time.current) }

          before do
            visit census_path
            select "Corporate governance census", from: "census_manifest"
            select "Test Setting", from: "corporate_governance_census[setting_id]"
            check "Corporate Governance (Multi-Step)"
            click_button "Save and continue"
          end

          it "shows user count based on setting participants and delegates" do
            expect(page).to have_content("There are currently 2 people eligible for voting")
          end
        end
      end
    end

    context "when registered participants census is selected" do
      before do
        select "Registered participants (dynamic)", from: "census_manifest"
        sleep 1
      end

      it "shows authorization handlers section" do
        expect(page).to have_content("Additional required authorizations to vote")
      end

      it "does not show setting selector" do
        expect(page).to have_no_select("corporate_governance_census[setting_id]")
      end

      context "when corporate governance verifier is checked" do
        before do
          check "Corporate Governance (Multi-Step)"
          sleep 1
        end

        it "shows setting selector for verifier" do
          expect(page).to have_select("internal_users[authorization_handlers_options][delegations_verifier][setting]", with_options: ["Test Setting", "Another Setting"])
        end

        context "when verifier setting is selected" do
          let!(:participant1) { create(:participant, setting:, email: "verif_user1@example.org") }
          let!(:participant2) { create(:participant, setting:, email: "verif_user2@example.org") }
          let!(:user1) { create(:user, organization:, email: "verif_user1@example.org") }
          let!(:user2) { create(:user, organization:, email: "verif_user2@example.org") }

          before do
            select "Test Setting", from: "internal_users[authorization_handlers_options][delegations_verifier][setting]"
            sleep 1
          end

          it "shows user count based on authorized users" do
            expect(page).to have_content(/\d+ person.*eligible for voting/)
          end
        end
      end
    end

    context "when switching between manifests" do
      let!(:participant1) { create(:participant, setting:, email: "switch_user1@example.org") }
      let!(:user1) { create(:user, organization:, email: "switch_user1@example.org") }

      it "does not cause state pollution" do
        # Start with corporate governance census
        select "Corporate governance census", from: "census_manifest"
        sleep 1

        select "Test Setting", from: "corporate_governance_census[setting_id]"
        sleep 1

        # Switch to registered participants
        select "Registered participants (dynamic)", from: "census_manifest"
        sleep 1

        expect(page).to have_no_select("corporate_governance_census[setting_id]")
        expect(page).to have_content("Additional required authorizations to vote")

        # Switch back to corporate governance census
        select "Corporate governance census", from: "census_manifest"
        sleep 1

        expect(page).to have_select("corporate_governance_census[setting_id]")
        expect(page).to have_content("Additional required authorizations to vote")
      end
    end

    context "when validating form submission" do
      context "with corporate governance census" do
        before do
          select "Corporate governance census", from: "census_manifest"
          sleep 1
        end

        it "shows validation error when no setting is selected" do
          click_button "Save and continue"
          expect(page).to have_content("There is an error in this field")
        end

        it "shows validation error when setting does not exist" do
          # Manually set an invalid setting_id via JavaScript
          page.execute_script("document.querySelector('#corporate_governance_census_setting_id').value = '99999'")
          click_button "Save and continue"
          expect(page).to have_content("There is an error in this field")
        end

        context "when setting belongs to different organization" do
          let!(:other_organization) { create(:organization) }
          let!(:other_setting) { create(:setting, organization: other_organization, active: true, title: { "en" => "Other Org Setting" }) }

          it "shows validation error when setting belongs to different organization" do
            # Manually set setting_id from different organization via JavaScript
            page.execute_script("document.querySelector('#corporate_governance_census_setting_id').value = '#{other_setting.id}'")
            click_button "Save and continue"
            expect(page).to have_content("There is an error in this field")
          end
        end

        context "when setting exists but is inactive" do
          let!(:inactive_setting) { create(:setting, organization:, active: false, title: { "en" => "Inactive Setting" }) }

          it "shows validation error when setting is inactive" do
            # Inactive settings should not appear in dropdown, but test direct assignment
            page.execute_script("document.querySelector('#corporate_governance_census_setting_id').value = '#{inactive_setting.id}'")
            click_button "Save and continue"
            expect(page).to have_content("There is an error in this field")
          end
        end

        context "when no settings exist for organization" do
          before do
            # Delete existing settings to test empty state
            setting.destroy!
            setting2.destroy!
            visit Decidim::EngineRouter.admin_proxy(component).election_census_path(election)
            select "Corporate governance census", from: "census_manifest"
            sleep 1
          end

          it "shows empty setting selector and validation error on submit" do
            expect(page).to have_select("corporate_governance_census[setting_id]", options: [""])
            click_button "Save and continue"
            expect(page).to have_content("There is an error in this field")
          end
        end
      end
    end
  end
end
