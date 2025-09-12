# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::DelegationForm do
  subject { described_class.from_params(attributes).with_context(current_organization: organization) }

  let(:organization) { create(:organization) }
  let(:granter) { create(:user, organization:) }
  let(:grantee) { create(:user, organization:) }
  let(:granter_email) { nil }
  let(:grantee_email) { nil }
  let(:attributes) do
    {
      granter_id: granter&.id,
      grantee_id: grantee&.id,
      granter_email: granter_email,
      grantee_email: grantee_email
    }
  end
  let!(:granter_user) { create(:user, organization:) }
  let!(:grantee_user) { create(:user, organization:) }

  context "when there's granter and grantee" do
    it { is_expected.to be_valid }

    context "when granter belongs to another organization" do
      let(:granter) { create(:user) }

      it { is_expected.not_to be_valid }
    end

    context "when grantee belongs to another organization" do
      let(:grantee) { create(:user) }

      it { is_expected.not_to be_valid }
    end
  end

  context "when granter is missing" do
    let(:granter) { nil }

    it { is_expected.not_to be_valid }

    context "and granter_email is present" do
      let(:granter_email) { granter_user.email }

      it { is_expected.to be_valid }

      context "and granter is not registered" do
        let(:granter_email) { "test@idontexist.com" }

        it { is_expected.not_to be_valid }
      end
    end
  end

  context "when grantee is missing" do
    let(:grantee) { nil }

    it { is_expected.not_to be_valid }

    context "and grantee_email is present" do
      let(:grantee_email) { grantee_user.email }

      it { is_expected.to be_valid }

      context "and grantee is not registered" do
        let(:grantee_email) { "test@idontexist.com" }

        it { is_expected.not_to be_valid }
      end
    end
  end

  describe "granter and grantee methods" do
    context "when using user IDs" do
      it "returns correct granter" do
        expect(subject.granter).to eq(granter)
      end

      it "returns correct grantee" do
        expect(subject.grantee).to eq(grantee)
      end
    end

    context "when using emails" do
      let(:granter) { nil }
      let(:grantee) { nil }
      let(:granter_email) { granter_user.email }
      let(:grantee_email) { grantee_user.email }

      it "finds granter by email" do
        expect(subject.granter).to eq(granter_user)
      end

      it "finds grantee by email" do
        expect(subject.grantee).to eq(grantee_user)
      end
    end

    context "when both ID and email are provided" do
      let(:granter_email) { "different@example.org" }
      let(:grantee_email) { "different@example.org" }

      it "prioritizes ID over email for granter" do
        expect(subject.granter).to eq(granter)
      end

      it "prioritizes ID over email for grantee" do
        expect(subject.grantee).to eq(grantee)
      end
    end
  end

  describe "validation error messages" do
    context "when granter is missing" do
      let(:granter) { nil }

      it "adds error to granter_email" do
        subject.valid?
        expect(subject.errors[:granter_email]).to be_present
      end
    end

    context "when grantee is missing" do
      let(:grantee) { nil }

      it "adds error to grantee_email" do
        subject.valid?
        expect(subject.errors[:grantee_email]).to be_present
      end
    end
  end

  describe "organization-specific user lookup" do
    context "when granter exists in different organization" do
      let(:other_organization) { create(:organization) }
      let(:granter_from_other_org) { create(:user, organization: other_organization, email: "granter@example.org") }
      let(:granter) { nil }
      let(:granter_email) { granter_from_other_org.email }

      it "does not find user from different organization" do
        expect(subject.granter).to be_nil
      end

      it { is_expected.not_to be_valid }
    end

    context "when grantee exists in different organization" do
      let(:other_organization) { create(:organization) }
      let(:grantee_from_other_org) { create(:user, organization: other_organization, email: "grantee@example.org") }
      let(:grantee) { nil }
      let(:grantee_email) { grantee_from_other_org.email }

      it "does not find user from different organization" do
        expect(subject.grantee).to be_nil
      end

      it { is_expected.not_to be_valid }
    end
  end

  describe "edge cases" do
    context "when both granter and grantee are the same user" do
      let(:grantee) { granter }

      it { is_expected.to be_valid }
    end

    context "when context has no current_organization" do
      subject { described_class.from_params(attributes).with_context(context) }

      let(:context) { {} }
      let(:attributes) do
        {
          granter_id: granter&.id,
          grantee_id: grantee&.id,
          granter_email: granter_email,
          grantee_email: grantee_email
        }
      end

      it "returns nil for current_organization" do
        expect(subject.send(:current_organization)).to be_nil
      end

      it "cannot find users without organization context" do
        expect(subject.granter).to be_nil
        expect(subject.grantee).to be_nil
      end

      it { is_expected.not_to be_valid }
    end
  end
end
