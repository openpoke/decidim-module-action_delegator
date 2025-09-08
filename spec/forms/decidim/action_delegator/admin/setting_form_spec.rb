# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::SettingForm do
  subject { described_class.from_params(attributes).with_context(context) }

  let(:organization) { create(:organization) }
  let(:attributes) do
    {
      title:,
      description:,
      max_grants: 5,
      authorization_method: authorization_method,
      copy_from_setting_id: copy_from_setting_id,
      active: active
    }
  end
  let(:title) { { ca: "Títol", es: "Título", en: "Title" } }
  let(:description) { { ca: "Descripció", es: "Descripción", en: "Description" } }
  let(:authorization_method) { :both }
  let(:copy_from_setting_id) { nil }
  let(:active) { false }
  let(:context) { { current_organization: organization } }

  context "when everything is OK" do
    it { is_expected.to be_valid }
  end

  describe "title validations" do
    context "when title is missing" do
      let(:title) { { ca: "", es: "", en: "" } }

      it { is_expected.to be_invalid }

      it "has error on title locales" do
        subject.valid?
        expect(subject.errors[:title_en]).to be_present
      end
    end

    context "when title is partially missing" do
      let(:title) { { ca: "Títol", es: "", en: "" } }

      it { is_expected.to be_invalid }

      it "has error on default locale field" do
        subject.valid?
        expect(subject.errors[:title_en]).to be_present
        expect(subject.errors[:title_es]).not_to be_present
      end
    end

    context "when title is present in all locales" do
      let(:title) { { ca: "Títol", es: "Título", en: "Title" } }

      it { is_expected.to be_valid }
    end
  end

  describe "description validations" do
    context "when description is missing" do
      let(:description) { { ca: "", es: "", en: "" } }

      it { is_expected.to be_valid }
    end

    context "when description is partially present" do
      let(:description) { { ca: "Descripció", es: "", en: "" } }

      it { is_expected.to be_valid }
    end
  end

  describe "max_grants validations" do
    context "when max_grants is missing" do
      let(:attributes) { super().except(:max_grants) }

      it { is_expected.to be_invalid }

      it "has error on max_grants" do
        subject.valid?
        expect(subject.errors[:max_grants]).to include("cannot be blank")
      end
    end

    context "when max_grants is zero" do
      let(:attributes) { super().merge(max_grants: 0) }

      it { is_expected.to be_invalid }

      it "has numericality error" do
        subject.valid?
        expect(subject.errors[:max_grants]).to include("must be greater than 0")
      end
    end

    context "when max_grants is negative" do
      let(:attributes) { super().merge(max_grants: -1) }

      it { is_expected.to be_invalid }
    end

    context "when max_grants is positive" do
      let(:attributes) { super().merge(max_grants: 10) }

      it { is_expected.to be_valid }
    end

    context "when max_grants is not a number" do
      let(:attributes) { super().merge(max_grants: "not_a_number") }

      it { is_expected.to be_invalid }
    end
  end

  describe "authorization_method validations" do
    context "when authorization_method is email" do
      let(:authorization_method) { :email }

      it { is_expected.to be_valid }
    end

    context "when authorization_method is phone" do
      let(:authorization_method) { :phone }

      it { is_expected.to be_valid }
    end

    context "when authorization_method is both" do
      let(:authorization_method) { :both }

      it { is_expected.to be_valid }
    end

    context "when authorization_method is missing" do
      let(:authorization_method) { nil }

      it { is_expected.to be_valid }
    end
  end

  describe "copy_from_setting_id validations" do
    context "when copy_from_setting_id is missing" do
      let(:copy_from_setting_id) { nil }

      it { is_expected.to be_valid }
    end

    context "when copy_from_setting_id is present" do
      let(:copy_from_setting_id) { 123 }

      it { is_expected.to be_valid }
    end
  end

  describe "active validations" do
    context "when active is true" do
      let(:active) { true }

      it { is_expected.to be_valid }
    end

    context "when active is false" do
      let(:active) { false }

      it { is_expected.to be_valid }
    end

    context "when active is missing" do
      let(:attributes) { super().except(:active) }

      it { is_expected.to be_valid }

      it "defaults to false" do
        expect(subject.active).to be false
      end
    end
  end

  describe "form attributes" do
    it "has all expected attributes" do
      expect(subject.title).to eq(title.stringify_keys)
      expect(subject.description).to eq(description.stringify_keys)
      expect(subject.max_grants).to eq(5)
      expect(subject.authorization_method).to eq(authorization_method.to_s)
      expect(subject.copy_from_setting_id).to eq(copy_from_setting_id)
      expect(subject.active).to eq(active)
    end
  end
end
