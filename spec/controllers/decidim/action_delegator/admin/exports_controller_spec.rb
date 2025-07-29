# frozen_string_literal: true

require "spec_helper"
require "support/shared_examples/export_controller"

module Decidim
  module ActionDelegator
    describe Admin::Consultations::ExportsController do
      routes { Decidim::ActionDelegator::AdminEngine.routes }

      let(:organization) { create(:organization) }
      let(:user) { create(:user, :admin, :confirmed, organization: organization) }
      let(:consultation) { create(:consultation, :finished, :published_results, organization: organization) }

      before do
        request.env["decidim.current_organization"] = organization
        sign_in user
      end

      describe "#create" do
        it_behaves_like "results export controller", "type_and_weight"
      end
    end
  end
end
