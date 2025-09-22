# frozen_string_literal: true

# require "spec_helper"
#
# describe Decidim::ActionDelegator::ParticipantsCsvImporter do
#   let(:current_user) { create(:user, :confirmed, :admin, organization: organization) }
#   let(:organization) { create(:organization) }
#   let(:consultation) { create(:consultation, organization: organization) }
#   let(:authorization_method) { "both" }
#   let(:current_setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
#   let(:valid_csv_file) { File.open("spec/fixtures/valid_participants.csv") }
#   let(:invalid_csv_file) { File.open("spec/fixtures/invalid_participants.csv") }
#   let(:csv_file_without_emails) { File.open("spec/fixtures/without_email.csv") }
#   let(:csv_file_without_phone) { File.open("spec/fixtures/without_phone.csv") }
#   let(:valid_csv_with_uppercase) { File.open("spec/fixtures/valid_participants_with_uppercase.csv") }
#   let(:csv_file_with_same_phones) { File.open("spec/fixtures/same_phones.csv") }
#   let(:weight) { 3 }
#
#   describe "#import!" do
#     let!(:ponderation) { create(:ponderation, setting: current_setting) }
#     let(:params) do
#       {
#         email: "user@example.org",
#         phone: "600000000",
#         weight: weight,
#         decidim_action_delegator_ponderation_id: ponderation.id
#       }
#     end
#
#     context "when the rows in the csv file are valid" do
#       subject { described_class.new(valid_csv_file, current_user, current_setting) }
#
#       it "Import all rows from csv file" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(4)
#       end
#
#       it "returns a summary of the import" do
#         import_summary = subject.import!
#
#         expect(import_summary[:error_rows]).to eq []
#         expect(import_summary[:imported_rows]).to eq 4
#         expect(import_summary[:total_rows]).to eq 4
#       end
#     end
#
#     context "when the rows in the csv file are not valid" do
#       subject { described_class.new(invalid_csv_file, current_user, current_setting) }
#
#       it "creates participants from valid rows" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(2)
#       end
#
#       it "returns a summary of the import" do
#         import_summary = subject.import!
#
#         expect(import_summary[:error_rows].pluck(:row_number)).to eq [1, 4]
#         expect(import_summary[:imported_rows]).to eq 2
#         expect(import_summary[:total_rows]).to eq 5
#       end
#     end
#
#     context "when participant with this email already exists" do
#       subject { described_class.new(valid_csv_file, current_user, current_setting) }
#
#       let!(:participant) { create(:participant, ponderation: ponderation, email: "user_@example.org", setting: current_setting) }
#
#       it "does not create a new participant" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(4)
#       end
#     end
#
#     context "when participant exists with another data" do
#       subject { described_class.new(valid_csv_file, current_user, current_setting) }
#
#       let!(:participant) { create(:participant, ponderation: ponderation, phone: "123456789", setting: current_setting) }
#
#       it "does not change the data of the existing participant" do
#         expect do
#           subject.import!
#         end.not_to change { participant.reload.phone }.from("123456789")
#       end
#     end
#
#     context "when participant with this phone already exists" do
#       subject { described_class.new(csv_file_with_same_phones, current_user, current_setting) }
#
#       let!(:participant) { create(:participant, ponderation: ponderation, phone: "123456789", setting: current_setting) }
#
#       it "does not create a new participant" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(1)
#       end
#
#       it "returns a summary of the import" do
#         import_summary = subject.import!
#
#         expect(import_summary[:skipped_rows].pluck(:row_number)).to eq [2, 3]
#         expect(import_summary[:imported_rows]).to eq 1
#         expect(import_summary[:total_rows]).to eq 3
#       end
#     end
#
#     context "when authorization_method :phone" do
#       subject { described_class.new(csv_file_without_emails, current_user, current_setting2) }
#
#       let(:consultation2) { create(:consultation, organization: organization) }
#       let(:authorization_method) { "phone" }
#       let(:current_setting2) { create(:setting, consultation: consultation2, authorization_method: authorization_method) }
#
#       it "imports all rows from the CSV file with phone numbers only" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(3)
#       end
#
#       it "returns a summary of the import with no error rows" do
#         import_summary = subject.import!
#
#         expect(import_summary[:error_rows]).to eq []
#         expect(import_summary[:imported_rows]).to eq 3
#         expect(import_summary[:total_rows]).to eq 3
#       end
#     end
#
#     context "when authorization_method :email" do
#       subject { described_class.new(csv_file_without_phone, current_user, current_setting3) }
#
#       let(:consultation3) { create(:consultation, organization: organization) }
#       let(:authorization_method) { "email" }
#       let(:current_setting3) { create(:setting, consultation: consultation3, authorization_method: authorization_method) }
#
#       it "imports all rows from the CSV file with emails only" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(3)
#       end
#
#       it "returns a summary of the import with no error rows" do
#         import_summary = subject.import!
#
#         expect(import_summary[:error_rows]).to eq []
#         expect(import_summary[:imported_rows]).to eq 3
#         expect(import_summary[:total_rows]).to eq 3
#       end
#     end
#
#     context "when the email is written in upper case" do
#       subject { described_class.new(valid_csv_with_uppercase, current_user, current_setting) }
#
#       it "creates a participant with the email in lower case" do
#         expect do
#           subject.import!
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(4)
#       end
#
#       it "returns a summary of the import with no error rows" do
#         import_summary = subject.import!
#
#         expect(import_summary[:error_rows]).to eq []
#         expect(import_summary[:imported_rows]).to eq 4
#         expect(import_summary[:total_rows]).to eq 4
#       end
#     end
#
#     context "when #assign_ponderation" do
#       subject { described_class.new(valid_csv_file, current_user, current_setting) }
#
#       let(:ponderation) { create(:ponderation, setting: current_setting, weight: 1) }
#
#       let(:email) { "example@example.org" }
#       let(:phone) { "123456789" }
#       let(:setting) { create(:setting) }
#       let(:invalid) { false }
#
#       let(:form) do
#         double(
#           invalid?: invalid,
#           email: email,
#           phone: phone,
#           decidim_action_delegator_ponderation_id: nil,
#           setting: current_setting,
#           weight: 1
#         )
#       end
#
#       it "assigns ponderation to participant" do
#         allow(form).to receive(:decidim_action_delegator_ponderation_id=).with(ponderation.id).and_return(ponderation.id)
#
#         expect do
#           subject.send(:process_participant, form)
#         end.to change(Decidim::ActionDelegator::Participant, :count).by(1)
#       end
#     end
#   end
# end
