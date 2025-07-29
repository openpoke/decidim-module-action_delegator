# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Admin::PonderationsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:consultation) { create(:consultation, organization: organization) }
      let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
      let(:authorization_method) { :both }
      let(:ponderation) { create(:ponderation, setting: setting) }
      let(:user) { create(:user, :admin, :confirmed, organization: organization) }
      let(:params) do
        { setting_id: setting.id }
      end
      let(:edit_params) do
        { setting_id: setting.id, id: ponderation.id }
      end

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#index" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:index, :ponderation, {})

          get :index, params: params
        end
      end

      describe "#new" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:create, :ponderation, {})

          get :new, params: params
        end
      end

      describe "#create" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:create, :ponderation, {})

          get :create, params: params
        end

        context "when successful" do
          let(:params) do
            { setting_id: setting.id, ponderation: { weight: 1.5, name: "Ponderation 1.5" } }
          end

          it "redirects to the ponderations list" do
            expect { post :create, params: params }.to change(Ponderation, :count).by(1)

            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.create.success"))
            expect(response).to redirect_to(setting_ponderations_path(setting))
          end
        end

        context "when unsuccessful" do
          let(:params) do
            { setting_id: setting.id, ponderation: { weight: 1.5, name: "" } }
          end

          it "renders the new form" do
            post :create, params: params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.create.error"))
            expect(response).to render_template(:new)
          end
        end
      end

      describe "#edit" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:update, :ponderation, {})

          get :edit, params: edit_params
        end
      end

      describe "#update" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:update, :ponderation, {})

          get :update, params: edit_params
        end

        context "when successful" do
          let(:edit_params) do
            { setting_id: setting.id, id: ponderation.id, ponderation: { weight: 1.5, name: "Ponderation 1.5" } }
          end

          it "redirects to the ponderations list" do
            put :update, params: edit_params

            expect(ponderation.reload.weight).to eq(1.5)
            expect(ponderation.reload.name).to eq("Ponderation 1.5")
            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.update.success"))
            expect(response).to redirect_to(setting_ponderations_path(setting))
          end
        end

        context "when unsuccessful" do
          let(:edit_params) do
            { setting_id: setting.id, id: ponderation.id, ponderation: { weight: 1.5, name: "" } }
          end

          it "renders the new form" do
            put :update, params: edit_params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.update.error"))
            expect(response).to render_template(:edit)
          end
        end
      end

      describe "#destroy" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:destroy, :ponderation, { resource: ponderation })

          get :destroy, params: edit_params
        end

        context "when successful" do
          let!(:ponderation) { create(:ponderation, setting: setting) }

          it "redirects to the ponderations list" do
            expect { delete :destroy, params: edit_params }.to change(Ponderation, :count).by(-1)

            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.destroy.success"))
            expect(response).to redirect_to(setting_ponderations_path(setting))
          end
        end

        context "when unsuccessful" do
          let!(:ponderation) { create(:ponderation, setting: setting) }

          before do
            allow_any_instance_of(Ponderation).to receive(:destroy).and_return(false) # rubocop:disable RSpec/AnyInstance
          end

          it "redirects to the ponderations list" do
            delete :destroy, params: edit_params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.ponderations.destroy.error"))
            expect(response).to redirect_to(setting_ponderations_path(setting))
          end
        end
      end
    end
  end
end
