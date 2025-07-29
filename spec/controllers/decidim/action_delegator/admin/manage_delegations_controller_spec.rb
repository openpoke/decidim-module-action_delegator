# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Admin
      describe ManageDelegationsController do
        routes { Decidim::ActionDelegator::AdminEngine.routes }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, :confirmed, :admin, organization: organization) }
        let(:consultation) { create(:consultation, organization: organization) }

        before do
          request.env["decidim.current_organization"] = organization
          sign_in user
        end

        describe "GET #new" do
          let(:setting) { create(:setting, consultation: consultation) }

          before do
            get :new, params: { setting_id: setting.id }
          end

          it "returns a success response" do
            expect(response).to be_successful
          end

          it "assigns an empty array of errors" do
            expect(assigns(:errors)).to eq []
          end
        end

        describe "POST #create" do
          let(:setting) { create(:setting, consultation: consultation) }
          let(:csv_file) { fixture_file_upload("spec/fixtures/valid_delegations.csv", "text/csv") }
          let!(:granter) { create(:user, :confirmed, email: "granter@example.org", organization: organization) }
          let!(:grantee) { create(:user, :confirmed, email: "grantee@example.org", organization: organization) }

          before do
            post :create, params: { setting_id: setting.id, csv_file: csv_file }
          end

          it "creates the delegatiosn" do
            expect(flash[:notice]).to eq I18n.t("decidim.action_delegator.admin.manage_delegations.create.success")
            expect(response).to redirect_to(setting_delegations_path(setting))
            perform_enqueued_jobs do
              expect(Decidim::ActionDelegator::Delegation.count).to eq(1)
              expect(Decidim::ActionDelegator::Delegation.first.granter).to eq(granter)
              expect(Decidim::ActionDelegator::Delegation.first.grantee).to eq(grantee)
            end
          end

          context "when granter is in another organization" do
            let(:granter) { create(:user, :confirmed, email: "granter@example.org") }

            it "does not create the delegation" do
              expect(flash[:notice]).to eq I18n.t("decidim.action_delegator.admin.manage_delegations.create.success")
              expect(response).to redirect_to(setting_delegations_path(setting))
              perform_enqueued_jobs do
                expect(Decidim::ActionDelegator::Delegation.count).to eq(0)
              end
            end
          end

          context "with invalid params" do
            let(:csv_file) { nil }

            it "redirects to the setting manage delegations path" do
              expect(response).to redirect_to(new_setting_manage_delegation_path)
            end
          end
        end
      end
    end
  end
end
