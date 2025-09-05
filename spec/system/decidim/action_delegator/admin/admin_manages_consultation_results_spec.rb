# frozen_string_literal: true

# # frozen_string_literal: true

# require "spec_helper"

# describe "Admin manages consultation results" do
#   let(:organization) { create(:organization) }
#   let(:user) { create(:user, :admin, :confirmed, organization: organization) }

#   let(:total_votes) { I18n.t("decidim.admin.consultations.results.total_votes", count: votes) }

#   let(:question) { create(:question, consultation: consultation) }
#   let(:response) { create(:response, question: question, title: { "ca" => "A" }) }
#   let(:other_response) { create(:response, question: question, title: { "ca" => "B" }) }

#   let!(:other_user) { create(:user, :admin, :confirmed, organization: organization) }
#   let!(:another_user) { create(:user, :admin, :confirmed, organization: organization) }
#   let!(:yet_another_user) { create(:user, :admin, :confirmed, organization: organization) }

#   let(:votes) { consultation.questions.first.total_votes }
#   let!(:consultation) { create(:consultation, :finished, :published_results, organization: organization) }
#   let(:setting) { create(:setting, consultation: consultation) }
#   let(:ponderation1) { create(:ponderation, setting: setting, name: "producer", weight: 2) }
#   let(:ponderation2) { create(:ponderation, setting: setting, name: "consumer", weight: 3) }
#   let(:ponderation3) { create(:ponderation, setting: setting, name: "consumer", weight: 1) }

#   before do
#     question.votes.create(author: user, response: response)
#     question.votes.create(author: other_user, response: response)
#     question.votes.create(author: another_user, response: response)
#     question.votes.create(author: yet_another_user, response: other_response)

#     create(:participant, setting: setting, decidim_user: user, ponderation: ponderation1)
#     create(:participant, setting: setting, decidim_user: other_user, ponderation: ponderation2)
#     create(:participant, setting: setting, decidim_user: another_user, ponderation: ponderation3)
#     create(:participant, setting: setting, decidim_user: yet_another_user, ponderation: ponderation3)

#     switch_to_host(organization.host)
#     login_as user, scope: :user
#   end

#   context "when in the consultation page" do
#     before do
#       visit decidim_admin_consultations.edit_consultation_path(consultation)
#       click_link "Results"
#     end

#     it "enables navigating to the default results page" do
#       click_link I18n.t("decidim.admin.menu.consultations_submenu.results")

#       expect(page).to have_current_path(decidim_admin_consultations.results_consultation_path(consultation))
#     end

#     it "enables navigating to the by membership type and weight results page" do
#       click_link I18n.t("decidim.action_delegator.admin.menu.consultations_submenu.by_type_and_weight")

#       expect(page).to have_current_path(decidim_admin_action_delegator.results_consultation_path(consultation))
#     end

#     it "enables navigating to the default results from the submenu link" do
#       click_link I18n.t("decidim.action_delegator.admin.menu.consultations_submenu.by_answer")

#       expect(page).to have_current_path(decidim_admin_consultations.results_consultation_path(consultation))
#     end

#     it "enables navigating to the sum of weights" do
#       click_link I18n.t("decidim.action_delegator.admin.menu.consultations_submenu.sum_of_weights")

#       within ".secondary-nav ul ul" do
#         expect(find(".is-active")).to have_link(href: decidim_admin_action_delegator.weighted_results_consultation_path(consultation))
#       end

#       expect(page).to have_current_path(decidim_admin_action_delegator.weighted_results_consultation_path(consultation))
#     end

#     context "when viewing a finished consultation from the sum of weights page" do
#       it "enables exporting to CSV" do
#         click_link I18n.t("decidim.action_delegator.admin.menu.consultations_submenu.sum_of_weights")
#         perform_enqueued_jobs { click_link(I18n.t("decidim.admin.consultations.results.export")) }

#         expect(page).to have_content(I18n.t("decidim.admin.exports.notice"))

#         expect(last_email.subject).to include("results", "csv")
#         expect(last_email.attachments.first.filename).to match(/^consultation_results.*\.zip$/)
#       end
#     end
#   end

#   context "when in question page" do
#     before { visit decidim_admin_consultations.edit_question_path(question) }

#     it "enables navigating to the results page" do
#       click_link I18n.t("decidim.admin.menu.consultations_submenu.results")

#       expect(page).to have_current_path(decidim_admin_consultations.results_consultation_path(question.consultation))
#     end
#   end

#   shared_examples "show results" do
#     it "shows votes by membership and weight type" do
#       visit decidim_admin_action_delegator.results_consultation_path(consultation)

#       expect(page).to have_content(/#{translated(consultation.questions.first.responses.first.title)}/i)
#       expect(page).to have_content(I18n.t("decidim.admin.consultations.results.membership_type"))
#       expect(page).to have_content(I18n.t("decidim.admin.consultations.results.membership_weight"))

#       expect(page).to have_content("Total: 5 votes / 0 delegated votes / 4 participants")
#       expect(page).to have_content("Total: 4 votes / 0 delegated votes / 4 participants")
#       expect(page).to have_content("Total: 1 votes / 0 delegated votes / 1 participants")

#       within ".table-list" do
#         expect(nth_row(1).find(".response-title")).to have_content("A")
#         expect(nth_row(1).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(1).find(".membership-weight")).to have_content(3)
#         expect(nth_row(1).find(".votes-count")).to have_content(1)

#         expect(nth_row(2).find(".response-title")).to have_content("A")
#         expect(nth_row(2).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(2).find(".membership-weight")).to have_content(1)
#         expect(nth_row(2).find(".votes-count")).to have_content(1)

#         expect(nth_row(3).find(".response-title")).to have_content("A")
#         expect(nth_row(3).find(".membership-type")).to have_content("producer")
#         expect(nth_row(3).find(".membership-weight")).to have_content(2)
#         expect(nth_row(3).find(".votes-count")).to have_content(1)

#         expect(nth_row(4).find(".response-title")).to have_content("B")
#         expect(nth_row(4).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(4).find(".membership-weight")).to have_content(1)
#         expect(nth_row(4).find(".votes-count")).to have_content(1)
#       end
#     end
#   end

#   context "when viewing a finished consultation with votes" do
#     context "without delegated votes" do
#       let(:extra_question) { create(:question, consultation: consultation) }
#       let(:extra_response) { create(:response, question: extra_question) }

#       before do
#         extra_question.votes.create(author: user, response: extra_response)
#       end

#       it_behaves_like "show results"

#       it "enables exporting to CSV" do
#         visit decidim_admin_action_delegator.results_consultation_path(consultation)
#         perform_enqueued_jobs { click_link(I18n.t("decidim.admin.consultations.results.export")) }

#         expect(page).to have_content(I18n.t("decidim.admin.exports.notice"))

#         expect(last_email.subject).to include("results", "csv")
#         expect(last_email.attachments.first.filename).to match(/^consultation_results.*\.zip$/)
#       end
#     end

#     context "with delegated votes" do
#       let(:setting) { create(:setting, consultation: consultation) }
#       let(:granter) { create(:user, :confirmed, organization: organization) }
#       let(:other_granter) { create(:user, :confirmed, organization: organization) }
#       let(:grantee) { create(:user, :confirmed, organization: organization) }

#       before do
#         create(:delegation, granter_id: granter.id, grantee_id: grantee.id, setting: setting)
#         create(:delegation, granter_id: other_granter.id, grantee_id: grantee.id, setting: setting)

#         question.votes.create(author: granter, response: response)
#         question.votes.create(author: other_granter, response: other_response)
#       end

#       it "shows votes by membership and weight type" do
#         visit decidim_admin_action_delegator.results_consultation_path(consultation)

#         expect(page).to have_content(/#{translated(consultation.questions.first.responses.first.title)}/i)
#         expect(page).to have_content(I18n.t("decidim.admin.consultations.results.membership_type"))
#         expect(page).to have_content(I18n.t("decidim.admin.consultations.results.membership_weight"))

#         expect(page).to have_content("Total: 6 votes / 2 delegated votes / 6 participants")

#         expect(nth_row(1).find(".response-title")).to have_content("A")
#         expect(nth_row(1).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(1).find(".membership-weight")).to have_content(3)
#         expect(nth_row(1).find(".votes-count")).to have_content(1)

#         expect(nth_row(2).find(".response-title")).to have_content("A")
#         expect(nth_row(2).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(2).find(".membership-weight")).to have_content(1)
#         expect(nth_row(2).find(".votes-count")).to have_content(1)

#         expect(nth_row(3).find(".response-title")).to have_content("A")
#         expect(nth_row(3).find(".membership-type")).to have_content("membership data not available")
#         expect(nth_row(3).find(".membership-weight")).to have_content("1.0")
#         expect(nth_row(3).find(".votes-count")).to have_content(1)

#         expect(nth_row(4).find(".response-title")).to have_content("A")
#         expect(nth_row(4).find(".membership-type")).to have_content("producer")
#         expect(nth_row(4).find(".membership-weight")).to have_content(2)
#         expect(nth_row(4).find(".votes-count")).to have_content(1)

#         expect(nth_row(5).find(".response-title")).to have_content("B")
#         expect(nth_row(5).find(".membership-type")).to have_content("consumer")
#         expect(nth_row(5).find(".membership-weight")).to have_content(1)
#         expect(nth_row(5).find(".votes-count")).to have_content(1)
#       end

#       it "enables exporting to CSV" do
#         visit decidim_admin_action_delegator.results_consultation_path(consultation)
#         perform_enqueued_jobs { click_link(I18n.t("decidim.admin.consultations.results.export")) }

#         expect(page).to have_content(I18n.t("decidim.admin.exports.notice"))

#         expect(last_email.subject).to include("results", "csv")
#         expect(last_email.attachments.first.filename).to match(/^consultation_results.*\.zip$/)
#       end
#     end
#   end

#   context "when viewing an unfinished consultation" do
#     let(:consultation) { create(:consultation, :active, :unpublished_results, organization: organization) }
#     let(:extra_question) { create(:question, consultation: consultation) }
#     let(:extra_response) { create(:response, question: extra_question) }

#     before do
#       extra_question.votes.create(author: user, response: extra_response)
#     end

#     it "enables the export button" do
#       visit decidim_admin_action_delegator.results_consultation_path(consultation)

#       within "#export-consultation-results" do
#         expect(page).to have_no_css(".disabled")
#         expect(page).to have_link(I18n.t("decidim.admin.consultations.results.export"))
#       end
#     end

#     it_behaves_like "show results"

#     context "when preview results is disabled" do
#       before do
#         allow(Decidim::ActionDelegator).to receive(:admin_preview_results).and_return(false)
#       end

#       it "does not show any response" do
#         visit decidim_admin_action_delegator.results_consultation_path(consultation)
#         expect(page).to have_content(I18n.t("decidim.admin.consultations.results.not_visible"))
#       end
#     end
#   end

#   context "when viewing a consultation with unpublished results" do
#     let!(:consultation) { create(:consultation, :finished, :unpublished_results, organization: organization) }

#     it "enables the export button" do
#       visit decidim_admin_action_delegator.results_consultation_path(consultation)

#       within "#export-consultation-results" do
#         expect(page).to have_no_css(".disabled")
#         expect(page).to have_link(I18n.t("decidim.admin.consultations.results.export"))
#       end
#     end

#     it "shows the responses" do
#       visit decidim_admin_action_delegator.results_consultation_path(consultation)
#       expect(page).to have_xpath(".//table/tbody[1]/tr[4]")
#     end
#   end

#   def nth_row(number)
#     find(:xpath, ".//tbody[1]/tr[#{number}]")
#   end
# end
