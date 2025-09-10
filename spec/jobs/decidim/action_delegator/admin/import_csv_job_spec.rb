# frozen_string_literal: true

require "spec_helper"

RSpec.describe Decidim::ActionDelegator::Admin::ImportCsvJob do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, organization:) }
  let(:current_setting) { create(:setting, organization:) }

  describe "import delegations" do
    let(:valid_csv_file) { File.open("spec/fixtures/valid_delegations.csv") }

    let!(:granter_email) { "granter@example.org" }
    let!(:grantee_email) { "grantee@example.org" }
    let!(:granter) { create(:user, email: granter_email, organization:) }
    let!(:grantee) { create(:user, email: grantee_email, organization:) }

    let(:params) do
      {
        granter_id: granter.id,
        grantee_id: grantee.id
      }
    end

    let(:importer) { Decidim::ActionDelegator::DelegationsCsvImporter.new(valid_csv_file, current_user, current_setting) }
    let(:import_summary) { importer.import! }
    let(:importer_type) { "DelegationsCsvImporter" }

    before do
      allow(Decidim::ActionDelegator::DelegationsCsvImporter).to receive(:new).with(valid_csv_file, current_user, current_setting).and_return(importer)
      allow(importer).to receive(:import!).and_return(import_summary)
      allow(Decidim::ActionDelegator::ImportMailer)
        .to receive(:import)
        .with(current_user, import_summary, "spec/fixtures/details.csv")
        .and_return(double("mailer", deliver_later: true))
    end

    it "imports delegations CSV file and sends email notification" do
      expect { described_class.perform_now(importer_type, valid_csv_file, current_user, current_setting) }.not_to raise_error
      expect(importer).to have_received(:import!).once
      expect(Decidim::ActionDelegator::ImportMailer)
        .to have_received(:import)
        .once
        .with(current_user, import_summary, "spec/fixtures/details.csv")
    end

    it "handles errors during import" do
      allow(importer).to receive(:import!).and_raise(StandardError.new("Import error"))
      expect { described_class.perform_now(importer_type, valid_csv_file, current_user, current_setting) }.to raise_error(StandardError, "Import error")
    end
  end

  describe "import participants" do
    let(:valid_csv_file) { File.open("spec/fixtures/valid_participants.csv") }
    let(:weight) { 3 }
    let!(:ponderation) { create(:ponderation, setting: current_setting) }
    let(:params) do
      {
        email: "email@example.org",
        phone: "600000000",
        weight: weight,
        decidim_action_delegator_ponderation_id: ponderation.id
      }
    end

    let(:importer) { Decidim::ActionDelegator::ParticipantsCsvImporter.new(valid_csv_file, current_user, current_setting) }
    let(:import_summary) { importer.import! }
    let(:importer_type) { "ParticipantsCsvImporter" }

    before do
      allow(Decidim::ActionDelegator::ParticipantsCsvImporter).to receive(:new).with(valid_csv_file, current_user, current_setting).and_return(importer)
      allow(importer).to receive(:import!).and_return(import_summary)
      allow(Decidim::ActionDelegator::ImportMailer)
        .to receive(:import)
        .with(current_user, import_summary, "spec/fixtures/details.csv")
        .and_return(double("mailer", deliver_later: true))
    end

    it "imports participants CSV file and sends email notification" do
      expect { described_class.perform_now(importer_type, valid_csv_file, current_user, current_setting) }.not_to raise_error
      expect(importer).to have_received(:import!).once
      expect(Decidim::ActionDelegator::ImportMailer)
        .to have_received(:import)
        .once
        .with(current_user, import_summary, "spec/fixtures/details.csv")
    end

    it "handles errors during import" do
      allow(importer).to receive(:import!).and_raise(StandardError.new("Import error"))
      expect { described_class.perform_now(importer_type, valid_csv_file, current_user, current_setting) }.to raise_error(StandardError, "Import error")
    end
  end
end
