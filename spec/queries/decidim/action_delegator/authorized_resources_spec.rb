# frozen_string_literal: true

require "rails_helper"

module Decidim
  module ActionDelegator
    describe AuthorizedResources do
      let(:component) { create(:component) }
      let(:election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "delegations_verifier" => {} } }) }
      let(:another_election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "some_other_verifier" => {}, "delegations_verifier" => {} } }) }
      let(:invalid_election) { create(:election, component:, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "some_other_verifier" => {} } }) }
      let(:another_invalid_election) { create(:election, component:, census_manifest: "csv_census", census_settings: { "authorization_handlers" => { "delegations_verifier" => {} } }) }
      let(:external_election) { create(:election, census_manifest: "internal_users", census_settings: { "authorization_handlers" => { "delegations_verifier" => {} } }) }
      let(:setting) { double("Setting", organization: component.organization) }

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
