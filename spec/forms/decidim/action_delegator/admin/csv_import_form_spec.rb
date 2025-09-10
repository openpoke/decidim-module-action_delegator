# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::CsvImportForm do
  subject { described_class.from_params(attributes).with_context(context) }

  let(:organization) { create(:organization) }
  let(:setting) { create(:setting, organization: organization) }
  let(:context) { { current_organization: organization } }
  let(:csv_file) { fixture_file_upload("spec/fixtures/valid_participants.csv", "text/csv") }
  let(:setting_id) { setting.id }
  let(:attributes) do
    {
      csv_file: csv_file,
      setting_id: setting_id
    }
  end

  context "when everything is OK" do
    it { is_expected.to be_valid }
  end

  describe "csv_file validations" do
    context "when csv_file is missing" do
      let(:csv_file) { nil }

      it { is_expected.not_to be_valid }

      it "has error on csv_file" do
        subject.valid?
        expect(subject.errors[:csv_file]).to include("cannot be blank")
      end
    end

    context "when csv_file has wrong content type" do
      let(:csv_file) { fixture_file_upload("spec/fixtures/valid_participants.csv", "image/jpeg") }

      it { is_expected.not_to be_valid }

      it "has file content type error" do
        subject.valid?
        expect(subject.errors[:csv_file]).to be_present
      end
    end

    context "when csv_file is a valid CSV" do
      let(:csv_file) { fixture_file_upload("spec/fixtures/valid_participants.csv", "text/csv") }

      it { is_expected.to be_valid }
    end

    context "when csv_file is a text file with csv extension" do
      let(:csv_file) { fixture_file_upload("spec/fixtures/valid_participants.csv", "text/plain") }

      it { is_expected.not_to be_valid }
    end
  end

  describe "setting_id validations" do
    context "when setting_id is missing" do
      let(:setting_id) { nil }

      it { is_expected.to be_valid }
    end

    context "when setting_id is present" do
      let(:setting_id) { setting.id }

      it { is_expected.to be_valid }
    end

    context "when setting_id is invalid" do
      let(:setting_id) { -1 }

      it { is_expected.to be_valid }
    end
  end

  describe "form attributes" do
    it "has correct attributes" do
      expect(subject.csv_file).to eq(csv_file)
      expect(subject.setting_id).to eq(setting_id)
    end

    context "when attributes are missing" do
      let(:attributes) { {} }

      it "handles missing attributes" do
        expect(subject.csv_file).to be_nil
        expect(subject.setting_id).to be_nil
      end
    end
  end
end
