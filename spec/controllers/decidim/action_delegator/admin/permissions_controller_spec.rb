# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Admin::PermissionsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:user) { create(:user, :admin, :confirmed, organization:) }
      let(:setting) { create(:setting, organization:) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#sync" do
        it "enqueues SyncParticipantsJob and redirects with success notice" do
          expect do
            post :sync, params: { setting_id: setting.id }
          end.to have_enqueued_job(SyncParticipantsJob).with(setting)

          expect(response).to redirect_to(settings_path)
          expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.permissions.sync.started"))
        end

        context "when setting does not exist" do
          it "enqueues job with nil setting" do
            expect do
              post :sync, params: { setting_id: 999_999 }
            end.to have_enqueued_job(SyncParticipantsJob).with(nil)

            expect(response).to redirect_to(settings_path)
            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.permissions.sync.started"))
          end
        end

        context "when setting belongs to different organization" do
          let(:other_organization) { create(:organization) }
          let(:other_setting) { create(:setting, organization: other_organization) }

          it "enqueues job with nil setting" do
            expect do
              post :sync, params: { setting_id: other_setting.id }
            end.to have_enqueued_job(SyncParticipantsJob).with(nil)

            expect(response).to redirect_to(settings_path)
            expect(flash[:notice]).to eq(I18n.t("decidim.action_delegator.admin.permissions.sync.started"))
          end
        end
      end
    end
  end
end
