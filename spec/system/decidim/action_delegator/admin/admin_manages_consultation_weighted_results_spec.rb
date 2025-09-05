# frozen_string_literal: true

# # frozen_string_literal: true

# require "spec_helper"

# describe "Admin manages sum of weight consultation results" do
#   let(:organization) { create(:organization) }
#   let(:user) { create(:user, :admin, :confirmed, organization: organization) }

#   let!(:question) { create(:question, consultation: consultation) }
#   let!(:response) { create(:response, question: question, title: { "ca" => "A" }) }

#   let!(:other_user) { create(:user, :confirmed, organization: organization) }

#   let(:setting) { create(:setting, consultation: consultation) }
#   let(:ponderation1) { create(:ponderation, setting: setting, name: "consumer", weight: 3) }

#   before do
#     # Regular vote
#     question.votes.create(author: user, response: response)
#     # Vote of a user with membership
#     question.votes.create(author: other_user, response: response)

#     create(:participant, setting: setting, decidim_user: other_user, ponderation: ponderation1)

#     switch_to_host(organization.host)
#     login_as user, scope: :user
#   end

#   context "when viewing a finished consultation with votes" do
#     let(:consultation) { create(:consultation, :finished, :published_results, organization: organization) }

#     it "shows total votes taking membership weight into account" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)

#       within_table("results") do
#         expect(find(".response-title")).to have_content("A")
#         expect(find(".votes-count")).to have_content(4)
#       end
#     end

#     it "enables exporting to CSV" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)
#       perform_enqueued_jobs { click_link(I18n.t("decidim.admin.consultations.results.export")) }

#       expect(page).to have_content(I18n.t("decidim.admin.exports.notice"))

#       expect(last_email.subject).to include("results", "csv")
#       expect(last_email.attachments.first.filename).to match(/^consultation_results.*\.zip$/)
#     end
#   end

#   context "when viewing an unfinished consultation" do
#     let!(:consultation) { create(:consultation, :active, :unpublished_results, organization: organization) }

#     it "enables the export button" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)

#       within "#export-consultation-results" do
#         expect(page).to have_no_css(".disabled")
#         expect(page).to have_link(I18n.t("decidim.admin.consultations.results.export"))
#       end
#     end

#     it "shows responses" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)
#       expect(page).to have_no_content(I18n.t("decidim.admin.consultations.results.not_visible"))
#     end

#     context "when mod is disabled" do
#       before do
#         allow(Decidim::ActionDelegator).to receive(:admin_preview_results).and_return(false)
#       end

#       it "does not show any response" do
#         visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)
#         expect(page).to have_content(I18n.t("decidim.admin.consultations.results.not_visible"))
#       end
#     end
#   end

#   context "when viewing a consultation with unpublished results" do
#     let!(:consultation) { create(:consultation, :finished, :unpublished_results, organization: organization) }

#     it "disables the export button" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)

#       within "#export-consultation-results" do
#         expect(page).to have_no_css(".disabled")
#         expect(page).to have_link(I18n.t("decidim.admin.consultations.results.export"))
#       end
#     end

#     it "shows the responses" do
#       visit decidim_admin_action_delegator.weighted_results_consultation_path(consultation)
#       expect(page).to have_xpath(".//table/tbody/tr[1]")
#     end
#   end
# end
