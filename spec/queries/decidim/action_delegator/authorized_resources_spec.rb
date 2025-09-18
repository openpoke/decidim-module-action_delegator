# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe AuthorizedResources do
      let(:component) { create(:elections_component) }
      let(:setting) { create(:setting, organization: component.organization) }
      let(:election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "delegations_verifier" => { "options" => { "setting" => setting.id.to_s } } } }) }
      let(:another_election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "some_other_verifier" => {}, "delegations_verifier" => { "options" => { "setting" => setting.id.to_s } } } }) }
      let(:invalid_election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "some_other_verifier" => {} } }) }
      let(:another_invalid_election) { create(:election, component:, census_manifest: "csv_census", census_settings: { "authorization_handlers" => { "delegations_verifier" => {} } }) }
      let(:external_election) { create(:election, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "delegations_verifier" => {} } }) }

      subject { described_class.new(setting:) }

      describe "#initialize" do
        it "assigns the setting" do
          expect(subject.instance_variable_get(:@setting)).to eq(setting)
        end
      end

      describe "#query" do
        it "returns the authorized resources" do
          expect(subject.query).to eq([election, another_election])
        end
      end
    end
  end
end
