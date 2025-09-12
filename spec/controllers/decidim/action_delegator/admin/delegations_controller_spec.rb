# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Admin::DelegationsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:user) { create(:user, :admin, :confirmed, organization:) }
      let(:setting) { create(:setting, organization:) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#index" do
        let!(:delegation) { create(:delegation, setting: setting) }

        it "renders decidim/action_delegator/admin/delegations layout" do
          get :index
          expect(response).to render_template("layouts/decidim/admin/users")
        end

        it "renders the index template" do
          get :index, params: { setting_id: setting.id }

          expect(response).to render_template(:index)
          expect(response).to have_http_status(:ok)
        end

        it "lists delegations of the current setting" do
          other_setting = create(:setting, organization:)
          other_setting_delegation = create(:delegation, setting: other_setting)

          get :index, params: { setting_id: setting.id }

          expect(controller.helpers.delegations).to include(delegation)
          expect(controller.helpers.delegations).not_to include(other_setting_delegation)
        end
      end

      describe "#new" do
        it "returns a success response" do
          get :new, params: { setting_id: setting.id }
          expect(response).to be_successful
        end
      end

      describe "#create" do
        let(:granter) { create(:user, organization:) }
        let(:grantee) { create(:user, organization:) }

        let(:params) do
          { delegation: { granter_id: granter.id, grantee_id: grantee.id }, setting_id: setting.id }
        end

        context "when the setting belongs to another organization" do
          let(:setting) { create(:setting) }

          it "does not create the delegation" do
            expect { post :create, params: params }.not_to change(Delegation, :count)
          end
        end

        context "when the granter belong to another organization" do
          let(:granter) { create(:user) }

          it "does not create the delegation" do
            expect { post :create, params: params }.not_to change(Delegation, :count)
          end
        end

        context "when the grantee belong to another organization" do
          let(:grantee) { create(:user) }

          it "does not create the delegation" do
            expect { post :create, params: params }.not_to change(Delegation, :count)
          end
        end

        context "when successful" do
          it "creates a delegation" do
            expect { post :create, params: params }.to change(Delegation, :count).by(1)
          end

          it "redirects to the setting index" do
            post :create, params: params
            expect(response).to redirect_to(setting_delegations_path(setting))
          end
        end

        context "when failed" do
          it "shows an error and renders new template" do
            post :create, params: { delegation: { granter_id: granter.id }, setting_id: setting.id }

            expect(response).to render_template(:new)
          end
        end
      end

      describe "#destroy" do
        let!(:delegation) { create(:delegation, setting: setting) }
        let(:params) { { id: delegation.id, setting_id: setting.id } }

        context "when the setting belongs to another organization" do
          let(:other_organization) { create(:organization) }
          let(:other_setting) { create(:setting, organization: other_organization) }
          let(:delegation) { create(:delegation, setting: other_setting) }

          it "does not destroy the delegation" do
            expect { delete :destroy, params: { id: delegation.id, setting_id: other_setting.id } }.not_to change(Delegation, :count)
          end
        end

        context "when successful" do
          it "destroys the specified delegation" do
            expect { delete :destroy, params: params }.to change(Delegation, :count).by(-1)

            expect(response).to redirect_to(setting_delegations_path(setting.id))
            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.delegations.destroy.success"))
          end
        end

        context "when failed" do
          before do
            allow_any_instance_of(Delegation).to receive(:destroy).and_return(false) # rubocop:disable RSpec/AnyInstance
          end

          it "shows an error" do
            delete :destroy, params: params

            expect(response).to redirect_to(setting_delegations_path(setting.id))
            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.delegations.destroy.error"))
          end
        end
      end
    end
  end
end
