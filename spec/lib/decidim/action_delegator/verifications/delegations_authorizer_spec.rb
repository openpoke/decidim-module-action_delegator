# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    module Verifications
      describe DelegationsAuthorizer do
        subject { authorizer.authorize }

        let(:organization) { create(:organization) }
        let(:user) { create(:user, organization: organization) }
        let(:component) { create(:elections_component, organization: organization) }
        let(:election) { create(:election, component: component, census_manifest: "internal_users", census_settings: census_settings) }
        let(:authorizer) { described_class.new(authorization, options, component, election) }

        let!(:authorization) do
          create(:authorization, :granted, user: user, name: "delegations_verifier", metadata: authorization_metadata)
        end

        describe "multi-setting authorization" do
          let!(:setting1) { create(:setting, organization: organization) }
          let!(:setting2) { create(:setting, organization: organization) }

          let!(:participant1) { create(:participant, setting: setting1, decidim_user: user, email: user.email) }
          let!(:participant2) { create(:participant, setting: setting2, decidim_user: user, email: user.email) }

          context "when user is authorized for setting1 but election uses setting2" do
            let(:authorization_metadata) { { "setting_id" => setting1.id } }
            let(:census_settings) do
              {
                "authorization_handlers" => {
                  "delegations_verifier" => {
                    "options" => { "setting" => setting2.id.to_s }
                  }
                }
              }
            end
            let(:options) { { "setting" => setting2.id.to_s } }

            it "allows voting across different settings" do
              # After fix: User authorized for setting1 can vote in elections that use setting2,
              # as long as they are a valid participant in setting2

              result = subject

              # Now this should succeed because we check participant status
              # in the election's setting, not the authorization's setting
              expect(result).to eq([:ok, {}])
            end
          end

          context "when user is authorized for setting1 and election uses setting1" do
            let(:authorization_metadata) { { "setting_id" => setting1.id } }
            let(:census_settings) do
              {
                "authorization_handlers" => {
                  "delegations_verifier" => {
                    "options" => { "setting" => setting1.id.to_s }
                  }
                }
              }
            end
            let(:options) { { "setting" => setting1.id.to_s } }

            it "allows voting" do
              result = subject
              expect(result).to eq([:ok, {}])
            end
          end
        end
      end
    end
  end
end
