# frozen_string_literal: true

require "spec_helper"
require "support/shared_examples/export_controller"

module Decidim
  module ActionDelegator
    module Admin
      describe Exports::SumOfWeightsController do
        routes { Decidim::ActionDelegator::AdminEngine.routes }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, :admin, :confirmed, organization: organization) }
        let(:consultation) { create(:consultation, :finished, :published_results, organization: organization) }

        before do
          request.env["decidim.current_organization"] = organization
          sign_in user
        end

        describe "#create" do
          it_behaves_like "results export controller", "sum_of_weights"
        end
      end
    end
  end
end
