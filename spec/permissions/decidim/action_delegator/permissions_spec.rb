# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Permissions do
  subject { described_class.new(user, permission_action, context).permissions.allowed? }

  let(:permission_action) { Decidim::PermissionAction.new(**action) }
  let(:context) { { question: question, delegation: delegation } }

  let(:organization) { create(:organization, available_authorizations: ["dummy_authorization_workflow"]) }
  let(:setting) { create(:setting, organization: organization, active: true, skip_injection: true) }
  let(:granter) { create(:user, :confirmed, organization: organization) }
  let(:user) { create(:user, organization: organization) }
  let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: user) }
  let(:question) do
    instance_double(
      "Question",
      can_be_voted_by?: can_be_voted_by,
      can_be_unvoted_by?: can_be_unvoted_by
    )
  end
  let(:can_be_voted_by) { true }
  let(:can_be_unvoted_by) { true }
  let(:authorized) { false }

  before do
    allow_any_instance_of(described_class).to receive(:authorized?).and_return(authorized) # rubocop:disable RSpec/AnyInstance
  end

  context "when voting a delegation" do
    let(:action) do
      { scope: :public, action: :vote_delegation, subject: :question }
    end

    context "and the grantee is verified" do
      let(:authorized) { true }

      context "and it was not voted yet" do
        let(:can_be_voted_by) { true }

        it { is_expected.to be(true) }
      end

      context "and it was already voted" do
        let(:can_be_voted_by) { false }

        it { is_expected.to be(false) }
      end
    end

    context "and the grantee is not verified" do
      it_behaves_like "permission is not set"
    end

    context "and the user is not the grantee" do
      let(:authorized) { true }
      let(:other_user) { create(:user, organization: organization) }
      let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: other_user) }

      it { is_expected.to be(false) }
    end
  end

  context "when unvoting a delegation" do
    let(:action) do
      { scope: :public, action: :unvote_delegation, subject: :question }
    end

    context "when the grantee is verified" do
      let(:authorized) { true }

      context "and it was already voted" do
        let(:can_be_unvoted_by) { true }

        it { is_expected.to be(true) }
      end

      context "and it was not voted yet" do
        let(:can_be_unvoted_by) { false }

        it { is_expected.to be(false) }
      end
    end

    context "when the grantee is not verified" do
      it_behaves_like "permission is not set"
    end

    context "when the user is not the grantee" do
      let(:authorized) { true }
      let(:other_user) { create(:user, organization: organization) }
      let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: other_user) }

      it { is_expected.to be(false) }
    end
  end
end
