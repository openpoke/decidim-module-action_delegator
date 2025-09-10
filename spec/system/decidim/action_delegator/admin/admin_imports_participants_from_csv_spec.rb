# frozen_string_literal: true

require "spec_helper"

describe "Admin imports participants from csv" do
  include Decidim::TranslationsHelper

  let(:i18n_scope) { "decidim.action_delegator.admin" }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization: organization) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  def import_csv(file)
    dynamically_attach_file("csv_import_csv_file", file.path)
    click_on "Import"
    perform_enqueued_jobs
    visit current_url
  end

  describe "import participants from csv" do
    let(:authorization_method) { "both" }
    let(:setting) { create(:setting, organization:, authorization_method:, active: true) }
    let!(:ponderation) { create(:ponderation, setting: setting, name: "consumer", weight: 1) }
    let(:valid_csv_file) { File.open("spec/fixtures/valid_participants.csv") }
    let(:invalid_csv_file) { File.open("spec/fixtures/invalid_participants.csv") }
    let(:repeated_data_csv_file) { File.open("spec/fixtures/repeated_data_participants.csv") }
    let(:ponderation_type_csv_file) { File.open("spec/fixtures/participant_with_ponderation_type.csv") }
    let(:empty_row_csv_file) { File.open("spec/fixtures/valid_participants_with_empty_row.csv") }

    before do
      visit decidim_admin_action_delegator.setting_participants_path(setting)
      click_on "Import CSV"
    end

    context "when CSV file was imported" do
      it "shows the flash" do
        dynamically_attach_file("csv_import_csv_file", valid_csv_file.path)
        click_on "Import"

        expect(page).to have_content("The import process has started")
      end
    end

    context "when the CSV has valid rows" do
      it "imports the participants" do
        import_csv(valid_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
      end
    end

    context "when the CSV has empty row" do
      it "the empty row is skipped and the import continues" do
        import_csv(empty_row_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
      end
    end

    context "when the CSV has invalid rows" do
      it "does not import the participants" do
        import_csv(invalid_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 2)
      end
    end

    context "when participant with this email already exists" do
      let(:participant) { create(:participant, email: "foo@example.org") }

      it "does not import the participants" do
        import_csv(valid_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
        expect(page).to have_content("foo@example.org", count: 1)
      end
    end

    context "when users already exists" do
      emails = %w(foo@example.org bar@example.org baz@example.org)
      users = []

      before do
        users = emails.map do |email|
          create(:user, :admin, :confirmed, organization: organization, email: email)
        end
      end

      it "shows user names" do
        import_csv(valid_csv_file)
        expect(page).to have_css("tr[data-participant-id]", count: 4)
        expect(page).to have_content(users[0].name, count: 1)
        expect(page).to have_content(users[1].name, count: 1)
        expect(page).to have_content(users[2].name, count: 1)
      end
    end

    context "when repeated data" do
      it "does not import the repeated participants" do
        import_csv(repeated_data_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
      end
    end

    context "when imported existing participants" do
      it "does not update the data of existing users in the table" do
        import_csv(valid_csv_file)
        click_on "Import CSV"
        import_csv(repeated_data_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
        expect(page).to have_content("9660000", count: 0)
      end
    end

    context "when the phone is already in use" do
      let!(:participant) { create(:participant, phone: "6660000") }

      it "does not import the participants" do
        import_csv(valid_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 4)
        expect(page).to have_content("6660000", count: 1)
      end
    end

    context "when the ponderation exists" do
      it "shows ponderation type" do
        import_csv(valid_csv_file)

        expect(page).to have_content("consumer", count: 1)
      end
    end

    context "when the ponderation is a string and does not exist" do
      it "does not import row" do
        import_csv(ponderation_type_csv_file)

        expect(page).to have_css("tr[data-participant-id]", count: 3)
        expect(page).to have_content("member", count: 0)
      end
    end
  end
end
