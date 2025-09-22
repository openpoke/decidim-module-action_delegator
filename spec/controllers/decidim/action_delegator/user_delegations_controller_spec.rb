# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe UserDelegationsController do
      routes { Decidim::ActionDelegator::Engine.routes }

      let(:organization) { create(:organization) }
      let(:user) { create(:user, :confirmed, organization: organization) }
      let(:granter) { create(:user, :confirmed, organization: organization) }
      let(:setting) { create(:setting, organization: organization) }
      let!(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: user) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "get #index" do
        it "show the list of delegations for the user" do
          get :index
          expect(response).to have_http_status(:ok)
          expect(controller.helpers.delegations).to eq([delegation])
        end
      end
    end
  end
end
