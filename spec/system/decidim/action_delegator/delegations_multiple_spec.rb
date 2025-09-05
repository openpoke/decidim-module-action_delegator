# frozen_string_literal: true

# # frozen_string_literal: true

# require "spec_helper"

# describe "Delegation vote" do
#   let(:organization) { create(:organization, available_authorizations: ["dummy_authorization_workflow"]) }
#   let(:question) { create(:question, :published, :multiple, consultation: consultation) }

#   context "when active consultation" do
#     let(:consultation) { create(:consultation, :active, organization: organization) }
#     let(:user) { create(:user, :confirmed, organization: organization) }

#     context "and unauthenticated user" do
#       before do
#         switch_to_host(organization.host)
#       end

#       it "renders the question page" do
#         visit decidim_consultations.question_path(question)
#         expect(page).to have_content(I18n.t("decidim.questions.vote_button.vote").upcase)
#       end
#     end

#     context "and authenticated user" do
#       let!(:response1) { create(:response, question: question) }
#       let!(:response2) { create(:response, question: question) }
#       let!(:response3) { create(:response, question: question) }
#       let(:responses) do
#         [response1, response2, response3]
#       end
#       let(:setting) { create(:setting, consultation: consultation) }
#       let(:granter) { create(:user, :confirmed, organization: organization) }
#       let!(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: user) }
#       let(:permissions) { { "vote" => { "authorization_handlers" => { "dummy_authorization_workflow" => {} } } } }

#       before do
#         switch_to_host(organization.host)
#         login_as user, scope: :user
#       end

#       context "and delegation is not voted" do
#         context "and the user didn't vote" do
#           before do
#             question.build_resource_permission.update!(permissions: permissions)
#           end

#           context "and the questions verification is not fulfilled" do
#             before do
#               visit decidim_consultations.question_path(question)
#             end

#             it "requires verification first" do
#               click_button(id: "delegations-button")
#               within "#delegations-modal" do
#                 expect(page).to have_content(t("decidim.questions.vote_button.verification_required").upcase)
#               end
#             end
#           end

#           context "and the questions verification is fulfilled" do
#             before do
#               Decidim::Authorization.create!(name: "dummy_authorization_workflow", decidim_user_id: user.id, granted_at: Time.zone.now)
#               visit decidim_consultations.question_path(question)
#             end

#             it "lets the user vote on behalf of another member" do
#               click_button(id: "delegations-button")
#               within "#delegations-modal" do
#                 click_link(I18n.t("decidim.questions.vote_button.vote"))
#               end

#               expect(page).to have_content(I18n.t("decidim.action_delegator.delegations_modal.callout"))

#               check "vote_id_#{response1.id}"
#               check "vote_id_#{response2.id}"
#               click_button(I18n.t("decidim.questions.vote_button.vote"))

#               click_button(id: "delegations-button")
#               within "#delegations-modal" do
#                 expect(page).to have_content(t("decidim.questions.vote_button.already_voted"))
#               end
#             end
#           end
#         end

#         context "and the user already voted" do
#           before do
#             create(:vote, author: user, question: question)
#             visit decidim_consultations.question_path(question)
#           end

#           it "lets the user vote on behalf of another member" do
#             click_button(id: "delegations-button")
#             within "#delegations-modal" do
#               click_link(I18n.t("decidim.questions.vote_button.vote"))
#             end

#             expect(page).to have_content(I18n.t("decidim.action_delegator.delegations_modal.callout"))

#             check "vote_id_#{response1.id}"
#             check "vote_id_#{response2.id}"
#             click_button(I18n.t("decidim.questions.vote_button.vote"))

#             click_button(I18n.t("decidim.action_delegator.delegations.has_delegations"))
#             within "#delegations-modal" do
#               expect(page).to have_content(t("decidim.questions.vote_button.already_voted"))
#             end
#           end
#         end
#       end

#       context "and delegation is voted" do
#         let!(:vote1) { create(:vote, author: granter, question: question, response: response1) }
#         let!(:vote2) { create(:vote, author: granter, question: question, response: response2) }
#         let(:permissions) { { "vote" => { "authorization_handlers" => { "dummy_authorization_workflow" => {} } } } }

#         before do
#           question.build_resource_permission.update!(permissions: permissions)
#           Decidim::Authorization.create!(name: "dummy_authorization_workflow", decidim_user_id: user.id, granted_at: Time.zone.now)
#           visit decidim_consultations.question_path(question)
#         end

#         it "lets the user unvote on behalf of another member" do
#           click_button(id: "delegations-button")
#           within "#delegations-modal" do
#             click_button(class: "delegation_unvote_button")
#           end

#           click_button(I18n.t("decidim.action_delegator.delegations.link"))
#           expect(page).to have_link(I18n.t("decidim.questions.vote_button.vote"))
#         end
#       end
#     end
#   end
# end
