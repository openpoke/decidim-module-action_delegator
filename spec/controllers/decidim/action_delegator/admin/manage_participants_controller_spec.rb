# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Admin
      describe ManageParticipantsController do
        routes { Decidim::ActionDelegator::AdminEngine.routes }

        let(:organization) { create(:organization) }
        let(:current_user) { create(:user, :confirmed, :admin, organization:) }
        let(:setting) { create(:setting, organization:, authorization_method:) }
        let(:authorization_method) { :both }

        before do
          request.env["decidim.current_organization"] = organization
          request.env["decidim.current_setting"] = setting
          sign_in current_user
        end

        describe "GET #new" do
          it "returns a success response" do
            get :new, params: { setting_id: setting.id }

            expect(response).to be_successful
          end

          it "assigns an empty array of errors" do
            get :new, params: { setting_id: setting.id }

            expect(assigns(:errors)).to eq []
          end

          it "assigns a new form" do
            get :new, params: { setting_id: setting.id }

            expect(assigns(:form)).to be_a(CsvImportForm)
          end
        end

        describe "POST #create" do
          let(:csv_file) do
            ActiveStorage::Blob.create_and_upload!(
              io: File.open("spec/fixtures/valid_participants.csv"),
              filename: "valid_participants.csv",
              content_type: "text/csv"
            )
          end
          let(:invalid_csv_file) do
            ActiveStorage::Blob.create_and_upload!(
              io: File.open("spec/fixtures/valid_participants.csv"),
              filename: "invalid.jpeg",
              content_type: "image/jpeg"
            )
          end

          context "with valid CSV file" do
            it "processes the CSV and redirects with success or shows form errors" do
              post :create, params: { setting_id: setting.id, csv_import: { csv_file: } }

              if response.redirect?
                expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.manage_participants.create.success"))
                expect(response).to redirect_to(setting_participants_path(setting))
              else
                expect(response).to render_template(:new)
              end
            end
          end

          context "with invalid form" do
            it "renders the new template" do
              post :create, params: { setting_id: setting.id, csv_import: { csv_file: invalid_csv_file } }

              expect(response).to render_template(:new)
            end

            it "assigns form errors" do
              post :create, params: { setting_id: setting.id, csv_import: { csv_file: invalid_csv_file } }

              expect(assigns(:form).errors).not_to be_empty
            end
          end

          context "when no file provided" do
            it "renders the new template with errors" do
              post :create, params: { setting_id: setting.id, csv_import: {} }

              expect(response).to render_template(:new)
            end
          end
        end

        describe "DELETE #destroy_all" do
          let!(:participants) { create_list(:participant, 3, setting: setting) }
          let(:params) { { setting_id: setting.id } }

          it "removes all and redirects to the participants page" do
            expect { delete :destroy_all, params: }.to change(Participant, :count).by(-3)
            expect(flash[:notice]).to eq(I18n.t("participants.remove_census.success", scope: "decidim.action_delegator.admin", participants_count: participants.count))
            expect(response).to redirect_to(setting_participants_path(setting))
          end

          context "when participants exist" do
            it "removes all participants since voted? always returns false" do
              expect { delete :destroy_all, params: }.to change(Participant, :count).by(-3)
              expect(flash[:notice]).to eq(I18n.t("participants.remove_census.success", scope: "decidim.action_delegator.admin", participants_count: participants.count))
              expect(response).to redirect_to(setting_participants_path(setting))
            end
          end
        end
      end
    end
  end
end
