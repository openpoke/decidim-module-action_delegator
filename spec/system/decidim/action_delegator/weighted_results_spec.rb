# # frozen_string_literal: true

# require "spec_helper"

# describe "Weighted results" do
#   let(:organization) { create(:organization, available_locales: [:en]) }
#   let(:user) { create(:user, :admin, :confirmed, organization: organization) }

#   let(:consultation) { create(:consultation, :finished, :published_results, organization: organization) }
#   let!(:question) { create(:question, consultation: consultation) }
#   let!(:responses) do
#     Array.new(2) { |i| create(:response, question: question, title: { "en" => "Option #{i + 1} Title" }) }
#   end

#   let!(:other_user) { create(:user, :confirmed, organization: organization) }

#   let(:setting) { create(:setting, consultation: consultation) }
#   let(:ponderation1) { create(:ponderation, setting: setting, name: "consumer", weight: 4) }

#   before do
#     # Regular vote
#     question.votes.create(author: user, response: responses.first)
#     # Vote of a user with membership
#     question.votes.create(author: other_user, response: responses.last)

#     create(:participant, setting: setting, decidim_user: other_user, ponderation: ponderation1)

#     switch_to_host(organization.host)
#     login_as user, scope: :user
#     visit decidim_consultations.consultation_path(consultation)
#   end

#   it "displays weighted results" do
#     expect(page).to have_content("Option 2")
#     expect(page).to have_content("4 votes out of 5")
#   end

#   context "when visiting the question page" do
#     before do
#       visit decidim_consultations.question_path(question)
#     end

#     it "displays weighted results" do
#       within first(".card--list__item") do
#         expect(page).to have_content("Option 2")
#         expect(page).to have_content(4)
#       end

#       within all(".card--list__item")[1] do
#         expect(page).to have_content("Option 1")
#         expect(page).to have_content(1)
#       end
#     end
#   end
# end
