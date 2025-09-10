# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::ParticipantForm do
  subject { described_class.from_params(attributes).with_context(context) }

  let(:context) do
    {
      setting: setting
    }
  end
  let(:setting) { create(:setting, :with_ponderations, authorization_method: authorization_method) }
  let(:authorization_method) { :both }
  let(:attributes) do
    {
      email: email,
      phone: phone,
      decidim_action_delegator_ponderation_id: decidim_action_delegator_ponderation_id
    }
  end
  let(:email) { "example@example.org" }
  let(:phone) { "123456789" }
  let(:decidim_action_delegator_ponderation_id) { setting.ponderations.first.id }

  context "when everything is OK" do
    it { is_expected.to be_valid }
  end

  context "when email is not present" do
    let(:email) { nil }

    it { is_expected.not_to be_valid }
  end

  context "when phone is not present" do
    let(:phone) { nil }

    it { is_expected.not_to be_valid }
  end

  context "when ponderation is not present" do
    let(:decidim_action_delegator_ponderation_id) { nil }

    it { is_expected.to be_valid }

    context "and ponderation belongs to a different setting" do
      let(:decidim_action_delegator_ponderation_id) { create(:ponderation).id }

      it { is_expected.not_to be_valid }
    end
  end

  context "when authorization method is phone" do
    let(:authorization_method) { :phone }
    let(:email) { nil }

    it { is_expected.to be_valid }

    context "and phone is not present" do
      let(:phone) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  context "when authorization method is email" do
    let(:authorization_method) { :email }
    let(:phone) { nil }

    it { is_expected.to be_valid }

    context "and email is not present" do
      let(:email) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  describe "phone sanitization" do
    let(:phone) { "+34 666 666 666" }

    it "sanitizes phone removing non-numeric characters except +" do
      expect(subject.phone).to eq("+34666666666")
    end

    context "when phone has parentheses and dashes" do
      let(:phone) { "+1 (555) 123-4567" }

      it "removes all non-numeric characters except +" do
        expect(subject.phone).to eq("+15551234567")
      end
    end

    context "when phone has spaces and dots" do
      let(:phone) { "666.555.4444" }

      it "removes dots and spaces" do
        expect(subject.phone).to eq("6665554444")
      end
    end

    context "when phone is nil" do
      let(:phone) { nil }

      it "returns nil" do
        expect(subject.phone).to be_nil
      end
    end

    context "when phone is empty string" do
      let(:phone) { "" }

      it "returns empty string" do
        expect(subject.phone).to eq("")
      end
    end
  end

  describe "weight attribute" do
    let(:attributes) { super().merge(weight: "5.5") }

    it "accepts weight as string" do
      expect(subject.weight).to eq("5.5")
    end

    context "when weight is missing" do
      let(:attributes) { super().except(:weight) }

      it { is_expected.to be_valid }
    end
  end

  describe "setting and authorization_method methods" do
    it "returns setting from context" do
      expect(subject.setting).to eq(setting)
    end

    it "returns authorization_method from setting" do
      expect(subject.authorization_method).to eq(setting.authorization_method.to_s)
    end

    context "when setting is nil" do
      let(:context) { { setting: nil } }

      it "returns nil for setting" do
        expect(subject.setting).to be_nil
      end

      it "returns nil for authorization_method" do
        expect(subject.authorization_method).to be_nil
      end
    end
  end

  describe "complex validation scenarios" do
    context "when ponderation belongs to different setting and is required" do
      let(:other_setting) { create(:setting, :with_ponderations) }
      let(:decidim_action_delegator_ponderation_id) { other_setting.ponderations.first.id }

      it { is_expected.not_to be_valid }

      it "has error on ponderation_id" do
        subject.valid?
        expect(subject.errors[:decidim_action_delegator_ponderation_id]).to include("is invalid")
      end
    end

    context "when all fields are properly filled for 'both' authorization" do
      let(:authorization_method) { :both }
      let(:email) { "participant@example.org" }
      let(:phone) { "+34666666666" }
      let(:decidim_action_delegator_ponderation_id) { setting.ponderations.first.id }

      it { is_expected.to be_valid }

      it "has all required attributes" do
        expect(subject.email).to eq("participant@example.org")
        expect(subject.phone).to eq("+34666666666")
        expect(subject.decidim_action_delegator_ponderation_id).to eq(setting.ponderations.first.id)
      end
    end
  end
end
