# frozen_string_literal: true

# require "spec_helper"
#
# describe "Corporate Governance Verifier request" do
#   let!(:organization) do
#     create(:organization, available_authorizations: ["delegations_verifier"])
#   end
#   let!(:user) { create(:user, :confirmed, password: "decidim123456789", organization: organization) }
#   let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
#   let(:consultation) { create(:consultation, organization: organization) }
#   let(:authorization_method) { :email }
#   let!(:participant) { create(:participant, phone: phone, email: email, setting: setting) }
#   let(:phone) { "612345678" }
#   let(:email) { user.email }
#   let(:authorize_on_login) { true }
#
#   before do
#     allow(Decidim::ActionDelegator).to receive(:authorize_on_login).and_return(authorize_on_login)
#     switch_to_host(organization.host)
#     visit decidim.new_user_session_path
#   end
#
#   shared_examples "authorizes the user" do
#     it "log in and authorizes" do
#       fill_in "Email", with: user.email
#       fill_in "Password", with: "decidim123456789"
#       click_button "Log in"
#
#       expect(page).to have_content(user.name)
#       expect(page).to have_content("Congratulations. You've been successfully verified")
#       expect(page).to have_current_path(decidim.root_path, ignore_query: true)
#       expect(Decidim::Authorization.last.name).to eq("delegations_verifier")
#     end
#   end
#
#   shared_examples "does not authorize the user" do
#     it "log in and authorizes" do
#       fill_in "Email", with: user.email
#       fill_in "Password", with: "decidim123456789"
#       click_button "Log in"
#
#       expect(page).to have_content(user.name)
#       expect(page).to have_no_content("Congratulations. You've been successfully verified")
#       expect(page).to have_current_path(decidim.root_path, ignore_query: true)
#       expect(Decidim::Authorization.last).to be_nil
#     end
#   end
#
#   it_behaves_like "authorizes the user"
#
#   context "when authorize on login is disabled" do
#     let(:authorize_on_login) { false }
#
#     it_behaves_like "does not authorize the user"
#   end
#
#   context "when no active setting" do
#     let(:consultation) { create(:consultation, :finished, organization: organization) }
#
#     it_behaves_like "does not authorize the user"
#   end
#
#   context "when authorization method is not email" do
#     let(:authorization_method) { :both }
#
#     it_behaves_like "does not authorize the user"
#   end
# end
