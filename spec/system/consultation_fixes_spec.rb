# frozen_string_literal: true

require "spec_helper"

describe "Visit a consultation" do
  let(:organization) { create(:organization, available_locales: [:en]) }
  let!(:consultation) { create(:consultation, :published, organization: organization) }
  let!(:question) { create(:question, consultation: consultation) }
  let!(:hihglighted_question) { create(:question, consultation: consultation, decidim_scope_id: consultation.decidim_highlighted_scope_id) }
  let(:user) { create(:user, :confirmed, :admin, organization: organization) }
  let(:enabled) { true }

  before do
    allow(Decidim::ActionDelegator).to receive(:remove_duplicated_highlighted_questions).and_return(enabled)

    switch_to_host(organization.host)
  end

  context "when public view" do
    shared_examples "renders questions in two sets" do
      it "appear once only" do
        expect(page).to have_content(translated(question.title), count: 1)
        expect(page).to have_content(translated(hihglighted_question.title), count: 1)
        expect(page).to have_content("QUESTIONS FROM #{translated(consultation.highlighted_scope.name).upcase}")
        expect(page).to have_content("QUESTIONS FOR THIS CONSULTATION")
      end
    end

    shared_examples "renders questions in two sets two times" do
      it "appear once only" do
        expect(page).to have_content(translated(question.title), count: 1)
        expect(page).to have_content(translated(hihglighted_question.title), count: 2)
        expect(page).to have_content("QUESTIONS FROM #{translated(consultation.highlighted_scope.name).upcase}")
        expect(page).to have_content("QUESTIONS FOR THIS CONSULTATION")
      end
    end

    shared_examples "renders questions in hihglighted section only" do
      it "appear once only" do
        expect(page).to have_content(translated(question.title), count: 1)
        expect(page).to have_content(translated(hihglighted_question.title), count: 1)
        expect(page).to have_content("QUESTIONS FROM #{translated(consultation.highlighted_scope.name).upcase}")
        expect(page).to have_no_content("QUESTIONS FOR THIS CONSULTATION")
      end
    end

    shared_examples "renders questions in hihglighted section and leave empty regular section" do
      it "appear once only" do
        expect(page).to have_content(translated(question.title), count: 1)
        expect(page).to have_content(translated(hihglighted_question.title), count: 1)
        expect(page).to have_content("QUESTIONS FROM #{translated(consultation.highlighted_scope.name).upcase}")
        expect(page).to have_content("QUESTIONS FOR THIS CONSULTATION")
      end
    end

    shared_examples "renders questions in regular section only" do
      it "appear once only" do
        expect(page).to have_content(translated(question.title), count: 1)
        expect(page).to have_content(translated(hihglighted_question.title), count: 1)
        expect(page).to have_no_content("QUESTIONS FROM #{translated(consultation.highlighted_scope.name).upcase}")
        expect(page).to have_content("QUESTIONS FOR THIS CONSULTATION")
      end
    end

    before do
      visit decidim_consultations.consultation_path(consultation)
    end

    it_behaves_like "renders questions in two sets"

    context "when question has no scopes" do
      let(:question) { create(:question, consultation: consultation, decidim_scope_id: nil) }

      it_behaves_like "renders questions in two sets"
    end

    context "when all questions have the highlighted scope" do
      let(:question) { create(:question, consultation: consultation, decidim_scope_id: consultation.decidim_highlighted_scope_id) }

      it_behaves_like "renders questions in hihglighted section only"
    end

    context "when all questions have a regular scope" do
      let(:hihglighted_question) { create(:question, consultation: consultation) }

      it_behaves_like "renders questions in regular section only"
    end

    context "when remove duplicated option is disabled" do
      let(:enabled) { false }

      it_behaves_like "renders questions in two sets two times"
    end
  end

  context "when admin" do
    before do
      login_as user, scope: :user
      visit decidim_admin_consultations.consultations_path
    end

    it "does not show the deprecation warning" do
      expect(page).to have_no_content("Consultations module will be deprecated in the near future.")
    end
  end
end
