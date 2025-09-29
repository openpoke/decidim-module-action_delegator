# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe ElectionSettings do
      let(:organization) { create(:organization) }
      let(:component) { create(:elections_component, organization: organization) }
      let!(:setting1) { create(:setting, organization: organization) }
      let!(:setting2) { create(:setting, organization: organization) }
      let!(:other_setting) { create(:setting, organization: organization) }

      subject { described_class.new(election) }

      describe "#initialize" do
        let(:election) { create(:election, component: component) }

        it "assigns the election" do
          expect(subject.instance_variable_get(:@election)).to eq(election)
        end
      end

      describe "#query" do
        context "when election has delegations_verifier configured with single setting" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => setting1.id
                    }
                  }
                }
              }
            )
          end

          it "returns the specific setting" do
            expect(subject.query).to include(setting1)
            expect(subject.query).not_to include(setting2, other_setting)
            expect(subject.query.count).to eq(1)
          end
        end

        context "when election has delegations_verifier configured with multiple settings" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => [setting1.id, setting2.id]
                    }
                  }
                }
              }
            )
          end

          it "returns all specified settings" do
            expect(subject.query).to include(setting1, setting2)
            expect(subject.query).not_to include(other_setting)
            expect(subject.query.count).to eq(2)
          end
        end

        context "when election has no delegations_verifier configured" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {}
                }
              }
            )
          end

          it "returns Setting.none" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has delegations_verifier but no setting option" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {}
                  }
                }
              }
            )
          end

          it "returns Setting.none" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has delegations_verifier with blank setting" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => ""
                    }
                  }
                }
              }
            )
          end

          it "returns Setting.none" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has delegations_verifier with nil setting" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => nil
                    }
                  }
                }
              }
            )
          end

          it "returns Setting.none" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has invalid setting id" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users",
              census_settings: {
                "authorization_handlers" => {
                  "internal_users" => {},
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => 999_999
                    }
                  }
                }
              }
            )
          end

          it "returns empty result" do
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has no census_settings" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "internal_users"
            )
          end

          it "returns Setting.none" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election uses corporate_governance_census" do
          context "with setting_id configured" do
            let(:test_setting) { create(:setting) }
            let(:election) do
              create(:election,
                     census_manifest: "corporate_governance_census",
                     census_settings: { "setting_id" => test_setting.id })
            end

            subject { described_class.new(election) }

            it "returns the specific setting" do
              expect(subject.query).to include(test_setting)
              expect(subject.query.count).to eq(1)
            end
          end

          context "with no setting_id configured" do
            let(:election) do
              create(:election,
                     census_manifest: "corporate_governance_census",
                     census_settings: {})
            end

            subject { described_class.new(election) }

            it "returns Setting.none" do
              expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
              expect(subject.query.count).to eq(0)
            end
          end

          context "with blank setting_id" do
            let(:election) do
              create(:election,
                     census_manifest: "corporate_governance_census",
                     census_settings: { "setting_id" => "" })
            end

            subject { described_class.new(election) }

            it "returns Setting.none" do
              expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
              expect(subject.query.count).to eq(0)
            end
          end
        end

        context "when election has no census_manifest (unsupported)" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: nil,
              census_settings: {
                "authorization_handlers" => {
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => setting1.id
                    }
                  }
                }
              }
            )
          end

          it "returns Setting.none as this election is not handled by action_delegator" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end

        context "when election has unknown census_manifest" do
          let(:election) do
            create(
              :election,
              :published,
              :ongoing,
              component: component,
              census_manifest: "unknown_census",
              census_settings: {
                "authorization_handlers" => {
                  "delegations_verifier" => {
                    "options" => {
                      "setting" => setting1.id
                    }
                  }
                }
              }
            )
          end

          it "returns Setting.none as this census manifest is not handled by action_delegator" do
            expect(subject.query).to eq(Decidim::ActionDelegator::Setting.none)
            expect(subject.query.count).to eq(0)
          end
        end
      end
    end
  end
end
