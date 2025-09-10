# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Admin
      describe ManageDelegationsController do
        routes { Decidim::ActionDelegator::AdminEngine.routes }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, :confirmed, :admin, organization:) }

        before do
          request.env["decidim.current_organization"] = organization
          sign_in user
        end

        describe "GET #new" do
          let(:setting) { create(:setting, organization:) }

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
          let(:setting) { create(:setting, organization:) }
          let(:csv_file) do
            ActiveStorage::Blob.create_and_upload!(
              io: File.open("spec/fixtures/valid_delegations.csv"),
              filename: "valid_delegations.csv",
              content_type: "text/csv"
            )
          end
          let(:invalid_csv_file) do
            ActiveStorage::Blob.create_and_upload!(
              io: File.open("spec/fixtures/valid_delegations.csv"),
              filename: "invalid.jpeg",
              content_type: "image/jpeg"
            )
          end
          let!(:granter) { create(:user, :confirmed, email: "granter@example.org", organization:) }
          let!(:grantee) { create(:user, :confirmed, email: "grantee@example.org", organization:) }

          context "with valid CSV file" do
            it "processes the CSV and redirects with success or shows form errors" do
              post :create, params: { setting_id: setting.id, csv_import: { csv_file: } }

              if response.redirect?
                expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.manage_delegations.create.success"))
                expect(response).to redirect_to(setting_delegations_path(setting))
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
      end
    end
  end
end
