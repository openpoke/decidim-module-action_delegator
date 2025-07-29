# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Admin::ParticipantsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:consultation) { create(:consultation, organization: organization) }
      let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
      let(:authorization_method) { :both }
      let(:participant) { create(:participant, setting: setting) }
      let(:user) { create(:user, :admin, :confirmed, organization: organization) }
      let(:params) do
        { setting_id: setting.id }
      end
      let(:edit_params) do
        { setting_id: setting.id, id: participant.id }
      end

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#index" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:index, :participant, {})

          get :index, params: params
        end
      end

      describe "#new" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:create, :participant, {})

          get :new, params: params
        end
      end

      describe "#create" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:create, :participant, {})

          get :create, params: params
        end

        context "when successful" do
          let(:params) do
            { setting_id: setting.id, participant: { phone: "666", email: "some@email.com" } }
          end

          it "redirects to the participants list" do
            expect { post :create, params: params }.to change(Participant, :count).by(1)

            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.participants.create.success"))
            expect(response).to redirect_to(setting_participants_path(setting))
          end
        end

        context "when unsuccessful" do
          let(:params) do
            { setting_id: setting.id, participant: { phone: "666", email: "" } }
          end

          it "renders the new form" do
            post :create, params: params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.participants.create.error"))
            expect(response).to render_template(:new)
          end
        end
      end

      describe "#edit" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:update, :participant, {})

          get :edit, params: edit_params
        end
      end

      describe "#update" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:update, :participant, {})

          get :update, params: edit_params
        end

        context "when successful" do
          let(:edit_params) do
            { setting_id: setting.id, id: participant.id, participant: { phone: "666", email: "some@email.com" } }
          end

          it "redirects to the participants list" do
            put :update, params: edit_params

            expect(participant.reload.phone).to eq("666")
            expect(participant.reload.email).to eq("some@email.com")
            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.participants.update.success"))
            expect(response).to redirect_to(setting_participants_path(setting))
          end
        end

        context "when unsuccessful" do
          let(:edit_params) do
            { setting_id: setting.id, id: participant.id, participant: { phone: "666", email: "" } }
          end

          it "renders the new form" do
            put :update, params: edit_params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.participants.update.error"))
            expect(response).to render_template(:edit)
          end
        end
      end

      describe "#destroy" do
        it "authorizes the action" do
          expect(controller).to receive(:allowed_to?).with(:destroy, :participant, { resource: participant })

          get :destroy, params: edit_params
        end

        context "when successful" do
          let!(:participant) { create(:participant, setting: setting) }

          it "redirects to the participants list" do
            expect { delete :destroy, params: edit_params }.to change(Participant, :count).by(-1)

            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.participants.destroy.success"))
            expect(response).to redirect_to(setting_participants_path(setting))
          end
        end

        context "when unsuccessful" do
          let!(:participant) { create(:participant, setting: setting) }

          before do
            allow_any_instance_of(Participant).to receive(:destroy).and_return(false) # rubocop:disable RSpec/AnyInstance
          end

          it "redirects to the participants list" do
            delete :destroy, params: edit_params

            expect(flash[:error]).to eq(I18n.t("decidim.action_delegator.admin.participants.destroy.error"))
            expect(response).to redirect_to(setting_participants_path(setting))
          end
        end
      end
    end
  end
end
