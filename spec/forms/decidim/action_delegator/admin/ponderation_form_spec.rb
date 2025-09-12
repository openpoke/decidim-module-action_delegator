# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::PonderationForm do
  subject { described_class.from_params(attributes).with_context(context) }

  let(:context) do
    {
      setting: setting
    }
  end
  let(:setting) { create(:setting) }
  let(:attributes) do
    {
      weight: weight,
      name: name
    }
  end

  let(:weight) { 1.0 }

  let(:name) { "Ponderation name" }

  context "when everything is OK" do
    it { is_expected.to be_valid }
  end

  context "when weight is not present" do
    let(:weight) { nil }

    it { is_expected.not_to be_valid }
  end

  context "when name is not present" do
    let(:name) { nil }

    it { is_expected.not_to be_valid }
  end

  context "when name is not unique" do
    let!(:existing_ponderation) { create(:ponderation, name:, setting:) }

    it { is_expected.not_to be_valid }

    it "has error on name" do
      subject.valid?
      expect(subject.errors[:name]).to include("has already been taken")
    end

    context "and the setting is different" do
      let!(:existing_ponderation) { create(:ponderation, name:) }

      it { is_expected.to be_valid }
    end

    context "and the existing ponderation is being updated (same id)" do
      let!(:existing_ponderation) { create(:ponderation, name:, setting:) }
      let(:attributes) { super().merge(id: existing_ponderation.id) }

      it { is_expected.to be_valid }
    end

    context "and the existing ponderation is being updated (same id)" do
      let!(:existing_ponderation) { create(:ponderation, name: name, setting: setting) }
      let(:attributes) { super().merge(id: existing_ponderation.id) }

      it { is_expected.to be_valid }
    end
  end

  describe "weight validations" do
    context "when weight is zero" do
      let(:weight) { 0.0 }

      it { is_expected.not_to be_valid }

      it "has error message about being greater than 0" do
        subject.valid?
        expect(subject.errors[:weight]).to include("must be greater than 0")
      end
    end

    context "when weight is negative" do
      let(:weight) { -1.5 }

      it { is_expected.not_to be_valid }

      it "has error message about being greater than 0" do
        subject.valid?
        expect(subject.errors[:weight]).to include("must be greater than 0")
      end
    end

    context "when weight is a large number" do
      let(:weight) { 999.99 }

      it { is_expected.to be_valid }
    end

    context "when weight is not a valid decimal" do
      let(:weight) { "not_a_number" }

      it { is_expected.not_to be_valid }
    end
  end

  describe "name validations" do
    context "when name is empty string" do
      let(:name) { "" }

      it { is_expected.not_to be_valid }
    end

    context "when name is whitespace only" do
      let(:name) { "   " }

      it { is_expected.not_to be_valid }
    end

    context "when name is very long" do
      let(:name) { "a" * 256 }

      it { is_expected.to be_valid }
    end

    context "when name has special characters" do
      let(:name) { "Ponderation & Weight #1" }

      it { is_expected.to be_valid }
    end
  end

  describe "setting method" do
    it "returns setting from context" do
      expect(subject.setting).to eq(setting)
    end

    context "when context has no setting" do
      let(:context) { {} }

      it "returns nil" do
        expect(subject.setting).to be_nil
      end
    end
  end

  describe "name_uniqueness validation edge cases" do
    context "when setting is nil" do
      let(:context) { {} }
      let!(:existing_ponderation) { create(:ponderation, name: name) }

      it { is_expected.to be_valid }
    end

    context "when name has different case" do
      let(:name) { "Test Name" }
      let!(:existing_ponderation) { create(:ponderation, name: "test name", setting: setting) }

      it "allows same name with different case" do
        # Name uniqueness is case-sensitive
        expect(subject).to be_valid
      end
    end
  end

  describe "form attributes" do
    it "has correct attribute defaults" do
      form = described_class.from_params({}).with_context(context)
      expect(form.weight).to eq(1.0)
      expect(form.name).to be_nil
    end

    it "accepts and stores all attributes" do
      expect(subject.weight).to eq(weight)
      expect(subject.name).to eq(name)
    end
  end

  describe "weight validations" do
    context "when weight is zero" do
      let(:weight) { 0.0 }

      it { is_expected.not_to be_valid }

      it "has error message about being greater than 0" do
        subject.valid?
        expect(subject.errors[:weight]).to include("must be greater than 0")
      end
    end

    context "when weight is negative" do
      let(:weight) { -1.5 }

      it { is_expected.not_to be_valid }

      it "has error message about being greater than 0" do
        subject.valid?
        expect(subject.errors[:weight]).to include("must be greater than 0")
      end
    end

    context "when weight is a large number" do
      let(:weight) { 999.99 }

      it { is_expected.to be_valid }
    end

    context "when weight is not a valid decimal" do
      let(:weight) { "not_a_number" }

      it { is_expected.not_to be_valid }
    end
  end

  describe "name validations" do
    context "when name is empty string" do
      let(:name) { "" }

      it { is_expected.not_to be_valid }
    end

    context "when name is whitespace only" do
      let(:name) { "   " }

      it { is_expected.not_to be_valid }
    end

    context "when name is very long" do
      let(:name) { "a" * 256 }

      it { is_expected.to be_valid }
    end

    context "when name has special characters" do
      let(:name) { "Ponderation & Weight #1" }

      it { is_expected.to be_valid }
    end
  end

  describe "setting method" do
    it "returns setting from context" do
      expect(subject.setting).to eq(setting)
    end

    context "when context has no setting" do
      let(:context) { {} }

      it "returns nil" do
        expect(subject.setting).to be_nil
      end
    end
  end

  describe "name_uniqueness validation edge cases" do
    context "when setting is nil" do
      let(:context) { {} }
      let!(:existing_ponderation) { create(:ponderation, name:) }

      it { is_expected.to be_valid }
    end

    context "when name has different case" do
      let(:name) { "Test Name" }
      let!(:existing_ponderation) { create(:ponderation, name: "test name", setting:) }

      it "allows same name with different case" do
        # Name uniqueness is case-sensitive
        expect(subject).to be_valid
      end
    end
  end

  describe "form attributes" do
    it "has correct attribute defaults" do
      form = described_class.from_params({}).with_context(context)
      expect(form.weight).to eq(1.0)
      expect(form.name).to be_nil
    end

    it "accepts and stores all attributes" do
      expect(subject.weight).to eq(weight)
      expect(subject.name).to eq(name)
    end
  end
end
