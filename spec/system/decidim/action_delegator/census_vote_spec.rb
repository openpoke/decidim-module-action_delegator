# frozen_string_literal: true

require "spec_helper"

describe "Census vote" do
  let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier dummy_authorization_workflow)) }

  let(:consultation) { create(:consultation, :active, organization: organization) }
  let!(:response) { create(:response, question: question) }
  let(:question) { create(:question, :published, consultation: consultation) }
  let(:setting) { create(:setting, consultation: consultation, authorization_method: :email) }
  let!(:participant) { create(:participant, setting: setting, decidim_user: decidim_user, email: email) }
  let(:email) { decidim_user.email }
  let(:decidim_user) { create(:user, organization: organization) }
  let(:permissions) { { "vote" => { "authorization_handlers" => { "delegations_verifier" => {} } } } }
  let!(:authorization) { create(:authorization, :granted, name: name, user: user) }
  let(:name) { "dummy_authorization_workflow" }
  let(:user) { create(:user, :confirmed, organization: organization) }

  before do
    question.build_resource_permission.update!(permissions: permissions)
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit decidim_consultations.question_path(question)
  end

  shared_examples "requires verification" do
    let(:text) { "you need to be authorized with \"Corporate Governance\"" }
    it "requires verification first" do
      expect(page).to have_content("VERIFY YOUR ACCOUNT TO VOTE")

      click_button "Verify your account to vote"
      within "#authorizationModal" do
        expect(page).to have_content(text)
      end
    end
  end

  shared_examples "is allowed" do
    it "allows to vote" do
      click_link(id: "vote_button")
      click_button translated(response.title)
      click_button "Confirm"
      expect(page).to have_button(id: "unvote_button")
    end
  end

  it_behaves_like "requires verification"

  context "when the user has a verified authorization" do
    let(:name) { "delegations_verifier" }

    it_behaves_like "requires verification" do
      let(:text) { "Sorry, you can't perform this action as some of your authorization data doesn't match." }
    end

    context "and user is in the census as decidim user" do
      let(:decidim_user) { user }
      let(:email) { "foo@example.org" }

      it_behaves_like "is allowed"
    end

    context "and user is in the census via email" do
      let(:decidim_user) { nil }
      let(:email) { user.email }

      it_behaves_like "is allowed"
    end
  end
end
