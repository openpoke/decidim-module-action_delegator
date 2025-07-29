# frozen_string_literal: true

require "spec_helper"

describe "Visit a consultation" do
  let(:organization) { create(:organization, available_locales: [:en]) }
  let!(:consultation) { create(:consultation, :published, organization: organization) }
  let!(:question) { create(:question, consultation: consultation) }
  let!(:question2) { create(:question, :unpublished, consultation: consultation) }
  let!(:hihglighted_question) { create(:question, consultation: consultation, decidim_scope_id: consultation.decidim_highlighted_scope_id) }
  let!(:response1) { create(:response, question: question) }
  let!(:response2) { create(:response, question: question) }
  let(:user) { create(:user, :confirmed, :admin, organization: organization) }
  let(:enabled) { true }

  before do
    allow(Decidim::ActionDelegator).to receive(:remove_duplicated_highlighted_questions).and_return(enabled)

    switch_to_host(organization.host)
  end

  shared_examples "logged user callout" do
    it "renders callout" do
      expect(page).to have_content("You have answered 0 from a total of 2 questions")
      click_link("Review the summary of your vote here")
      within "#consultations-questions-summary-modal" do
        expect(page).to have_content("Did you answer?")
        expect(page).to have_content("Your votes in \"#{consultation.title["en"]}\"")
        expect(page).to have_link("Vote pending", href: decidim_consultations.question_path(question))
        expect(page).to have_link("Vote pending", href: decidim_consultations.question_path(hihglighted_question))
        expect(page).to have_no_link(href: decidim_consultations.question_path(question2))
      end
    end

    it "changes the callout" do
      expect(page).to have_content("You have answered 0 from a total of 2 questions")
      click_link("Review the summary of your vote here")
      within "#consultations-questions-summary-modal" do
        expect(page).to have_no_content("Already voted")
        click_link("Vote pending", href: decidim_consultations.question_path(question))
      end
      click_link("Vote")
      click_button response1.title["en"]
      click_button "Confirm"
      expect(page).to have_content("You have answered 1 from a total of 2 questions")
      click_link("Review the summary of your vote here")
      within "#consultations-questions-summary-modal" do
        expect(page).to have_content("Already voted")
        expect(page).to have_link("Vote pending", href: decidim_consultations.question_path(hihglighted_question))
      end
    end
  end

  context "when user logged in" do
    before do
      login_as user, scope: :user
      visit decidim_consultations.consultation_path(consultation)
    end

    context "when visiting a consultation" do
      it_behaves_like "logged user callout"
    end

    context "when visiting a question" do
      before do
        click_link("Take part", match: :first)
      end

      it "can view the callout" do
        expect(page).to have_content("Review the summary of your vote here")
        within "#vote_button" do
          expect(page).to have_content("Vote")
        end
        expect(page).to have_content("You have answered 0 from a total of 2 questions")
      end

      it_behaves_like "logged user callout"
    end
  end

  context "when user is not logged in" do
    before do
      visit decidim_consultations.consultation_path(consultation)
    end

    context "when visiting a consultation" do
      it "can visit the consultation" do
        expect(page).to have_no_content("Review the summary of your vote here")
        expect(page).to have_no_content("You have answered 0 from a total of 2 questions")
      end
    end

    context "when visiting a question" do
      before do
        click_link("Take part", match: :first)
      end

      it "can visit the consultation" do
        expect(page).to have_no_content("Review the summary of your vote here")
        within "#vote_button" do
          expect(page).to have_content("Vote")
        end
        expect(page).to have_no_content("You have answered 0 from a total of 2 questions")
      end
    end
  end
end
