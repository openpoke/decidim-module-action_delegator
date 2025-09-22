# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::DelegationsCsvImporter do
  let(:current_user) { create(:user, :confirmed, :admin, organization: organization) }
  let(:organization) { create(:organization) }
  let(:current_setting) { create(:setting, organization: organization) }
  let(:valid_csv_file) { File.open("spec/fixtures/valid_delegations.csv") }
  let(:invalid_csv_file) { File.open("spec/fixtures/invalid_delegations.csv") }
  let(:valid_csv_with_uppercase) { File.open("spec/fixtures/valid_delegations_with_uppercase.csv") }
  let(:valid_csv_with_blank_spaces) { File.open("spec/fixtures/valid_delegations_with_blank_spaces.csv") }

  let(:params) do
    {
      granter_id: granter.id,
      grantee_id: grantee.id
    }
  end

  let!(:granter_email) { "granter@example.org" }
  let!(:grantee_email) { "grantee@example.org" }
  let!(:granter) { create(:user, email: granter_email, organization: organization) }
  let!(:grantee) { create(:user, email: grantee_email, organization: organization) }

  describe "#import!" do
    context "when the rows in the csv file are valid" do
      subject { described_class.new(valid_csv_file, current_user, current_setting) }

      it "Import all rows from csv file" do
        expect do
          subject.import!
        end.to change(Decidim::ActionDelegator::Delegation, :count).by(1)
      end

      it "returns a summary of the import" do
        import_summary = subject.import!

        expect(import_summary[:error_rows]).to eq []
        expect(import_summary[:imported_rows]).to eq 1
        expect(import_summary[:total_rows]).to eq 1
      end
    end

    context "when the rows in the csv file are not valid" do
      subject { described_class.new(invalid_csv_file, current_user, current_setting) }

      it "creates delegations from valid rows" do
        expect do
          subject.import!
        end.not_to change(Decidim::ActionDelegator::Delegation, :count)
      end

      it "returns a summary of the import" do
        import_summary = subject.import!

        expect(import_summary[:error_rows].pluck(:row_number)).to eq [1]
        expect(import_summary[:imported_rows]).to eq 0
        expect(import_summary[:total_rows]).to eq 1
      end
    end

    context "when delegation already exists" do
      subject { described_class.new(valid_csv_file, current_user, current_setting) }

      let!(:delegation) { create(:delegation, setting: current_setting, granter_id: granter.id, grantee_id: grantee.id) }

      it "does not create a new delegation" do
        expect do
          subject.import!
        end.not_to change(Decidim::ActionDelegator::Delegation, :count)
      end
    end

    context "when the email is written in upper case" do
      subject { described_class.new(valid_csv_with_uppercase, current_user, current_setting) }

      it "creates a delegation with the email in lower case" do
        expect do
          subject.import!
        end.to change(Decidim::ActionDelegator::Delegation, :count).by(1)
      end

      it "returns a summary of the import with no error rows" do
        import_summary = subject.import!

        expect(import_summary[:error_rows]).to eq []
        expect(import_summary[:imported_rows]).to eq 1
        expect(import_summary[:total_rows]).to eq 1
      end
    end

    context "when the emails are written with blank spaces" do
      subject { described_class.new(valid_csv_with_blank_spaces, current_user, current_setting) }

      it "creates a delegation with the emails without spaces" do
        expect do
          subject.import!
        end.to change(Decidim::ActionDelegator::Delegation, :count).by(1)
      end

      it "returns a summary of the import with no error rows" do
        import_summary = subject.import!

        expect(import_summary[:error_rows]).to eq []
        expect(import_summary[:imported_rows]).to eq 1
        expect(import_summary[:total_rows]).to eq 1
      end
    end
  end
end
