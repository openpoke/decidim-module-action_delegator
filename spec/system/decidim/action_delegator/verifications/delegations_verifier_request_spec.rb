# frozen_string_literal: true

require "spec_helper"

describe "Corporate Governance Verifier request" do
  let!(:organization) do
    create(:organization, available_authorizations: ["delegations_verifier"])
  end
  let!(:user) { create(:user, :confirmed, organization: organization) }
  let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
  let(:consultation) { create(:consultation, organization: organization) }
  let(:authorization_method) { :both }
  let!(:participant) { create(:participant, phone: phone, email: email, setting: setting) }
  let(:phone) { "612345678" }
  let(:email) { user.email }
  let(:authorize_on_login) { true }

  before do
    allow(Decidim::ActionDelegator).to receive(:authorize_on_login).and_return(authorize_on_login)
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit decidim_delegations_verifier.root_path
  end

  it "Shows the required fields" do
    expect(page).to have_content("Authorize with Corporate Governance Verifier")
    within "#new_delegations_verifier_" do
      expect(page).to have_content("Email")
      expect(page).to have_css("input[value='#{email}'][readonly]")
      expect(page).to have_content("Mobile phone number")
      expect(page).to have_css("input[value='#{phone}'][readonly]")
    end
  end

  it "allows to authorize the user" do
    click_button "Send verification code"
    expect(page).to have_content("Thanks! We've sent an SMS to your phone")
  end

  context "when authorization method is phone" do
    let(:authorization_method) { :phone }

    it "Shows the required fields" do
      expect(page).to have_content("Authorize with Corporate Governance Verifier")
      within "#new_delegations_verifier_" do
        expect(page).to have_no_content("Email")
        expect(page).to have_no_css("input[value='#{email}'][readonly]")
        expect(page).to have_content("Mobile phone number")
        expect(page).to have_no_css("input[readonly]")
        expect(page).to have_field("input")
      end
    end

    it "allows to authorize the user" do
      fill_in "Mobile phone number", with: "600102030"
      click_button "Send verification code"
      expect(page).to have_content("There was a problem with your request")
      expect(page).to have_content("this phone number is not in the census")
      fill_in "Mobile phone number", with: "+34 #{phone}"
      click_button "Send verification code"
      expect(page).to have_content("Thanks! We've sent an SMS to your phone")
    end
  end

  context "when authorization method is email" do
    let(:authorization_method) { :email }

    it "automatically authorizes the user" do
      expect(page).to have_content("Congratulations. You've been successfully verified.")
    end

    context "when authorize on login is disabled" do
      let(:authorize_on_login) { false }

      it "Shows the required fields" do
        expect(page).to have_content("Authorize with Corporate Governance Verifier")
        within "#new_delegations_verifier_" do
          expect(page).to have_content("Email")
          expect(page).to have_css("input[value='#{email}'][readonly]")
          expect(page).to have_no_content("Mobile phone number")
          expect(page).to have_no_css("input[value='#{phone}']")
        end
      end

      it "allows to authorize the user" do
        click_button "Authorize my account"
        expect(page).to have_content("Congratulations. You've been successfully verified.")
      end
    end

    context "when no active setting" do
      let(:consultation) { create(:consultation, :finished, organization: organization) }

      it "does not authorize the user" do
        expect(page).to have_content("The Corporate Governance Verifier cannot be granted at this time as there are no active voting spaces")
      end
    end
  end
end
