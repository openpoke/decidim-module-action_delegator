# frozen_string_literal: true

require "spec_helper"

describe "Corporate Governance Verifier request" do
  let!(:organization) do
    create(:organization, available_authorizations: ["delegations_verifier"])
  end
  let!(:user) { create(:user, :confirmed, organization: organization) }
  let(:setting) { create(:setting, organization: organization, active: true, authorization_method: authorization_method, skip_injection: true) }
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
    expect(page).to have_css("input[readonly][value='#{email}']")
    expect(page).to have_css("input[readonly][value='#{phone}']")
  end

  it "allows to authorize the user" do
    click_button "Send verification code"
    expect(page).to have_content("Thanks! We have sent an SMS to your phone.")
  end

  context "when authorization method is phone" do
    let(:authorization_method) { :phone }

    it "Shows the required fields" do
      expect(page).to have_content("Authorize with Corporate Governance Verifier")
      expect(page).to have_no_css("input[value='#{email}'][readonly]")
      expect(page).to have_css("input[name$='[phone]']:not([readonly])")
    end

    it "allows to authorize the user" do
      find("input[name$='[phone]']").set("600102030")
      click_button "Send verification code"
      expect(page).to have_content("There was a problem with your request")
      expect(page).to have_text(/phone.*not in the census/i)
      find("input[name$='[phone]']").set("+34 #{phone}")
      click_button "Send verification code"
      expect(page).to have_content("Thanks! We have sent an SMS to your phone.")
    end
  end

  context "when authorization method is email" do
    let(:authorization_method) { :email }

    it "automatically authorizes the user" do
      expect(page).to have_content("Congratulations. You have been successfully verified.")
    end

    context "when authorize on login is disabled" do
      let(:authorize_on_login) { false }

      it "Shows the required fields" do
        expect(page).to have_content("Authorize with Corporate Governance Verifier")
        expect(page).to have_css("input[value='#{email}'][readonly]")
        expect(page).to have_no_css("input[value='#{phone}']")
      end

      it "allows to authorize the user" do
        click_button "Authorize my account"
        expect(page).to have_content("Congratulations. You have been successfully verified.")
      end
    end

    context "when no active setting" do
      let(:setting) { create(:setting, organization: organization, active: false, authorization_method: authorization_method, skip_injection: true) }

      it "does not authorize the user" do
        expect(page).to have_content("No resources found")
      end
    end
  end
end
