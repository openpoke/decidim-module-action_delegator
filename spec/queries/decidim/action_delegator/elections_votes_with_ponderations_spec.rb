# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe ElectionsVotesWithPonderations do
      subject { described_class.new(relation, settings) }

      let!(:organization) { create(:organization) }
      let!(:component) { create(:elections_component, organization:) }
      let!(:election) { create(:election, :published, :ongoing, :with_questions, component:) }
      let!(:question) { election.questions.first }
      let!(:response_option) { question.response_options.first }
      let!(:setting) { create(:setting, organization:) }
      let!(:settings) { Decidim::ActionDelegator::Setting.where(id: setting.id) }
      let(:relation) { question.response_options }

      describe "#initialize" do
        it "assigns the relation and settings" do
          expect(subject.instance_variable_get(:@relation)).to eq(relation)
          expect(subject.instance_variable_get(:@settings)).to eq(settings)
        end

        it "creates Arel table instances" do
          expect(subject.instance_variable_get(:@participants)).to be_a(Arel::Table)
          expect(subject.instance_variable_get(:@ponderations)).to be_a(Arel::Table)
          expect(subject.instance_variable_get(:@votes)).to be_a(Arel::Table)
        end

        it "generates correct user_global_id_prefix" do
          user_global_id_prefix = subject.instance_variable_get(:@user_global_id_prefix)
          expect(user_global_id_prefix).to match(/gid:\/\/.*\/Decidim::User\//)
        end
      end

      describe "#query" do
        context "when settings are present" do
          let!(:ponderation) { create(:ponderation, setting:, weight: 2.5) }
          let!(:user) { create(:user, :confirmed, organization:) }
          let!(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

          it "returns the relation with joins" do
            result = subject.query

            expect(result).to be_a(ActiveRecord::Relation)
            expect(result.count).to eq(question.response_options.count)
          end

          it "includes votes join in SQL" do
            sql = subject.query.to_sql

            expect(sql).to include("LEFT OUTER JOIN")
            expect(sql).to include("decidim_elections_votes")
          end

          it "includes participants join in SQL" do
            sql = subject.query.to_sql

            expect(sql).to include("decidim_action_delegator_participants")
            expect(sql).to include("decidim_action_delegator_setting_id")
          end

          it "includes ponderations join in SQL" do
            sql = subject.query.to_sql

            expect(sql).to include("decidim_action_delegator_ponderations")
          end

          context "with votes" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "connects votes through the joins" do
              result = subject.query

              expect(result.count).to be > 0
            end

            it "generates correct SQL for vote matching" do
              sql = subject.query.to_sql

              expect(sql).to include("CONCAT")
              expect(sql).to include("voter_uid")
            end
          end

          context "with multiple settings" do
            let!(:setting2) { create(:setting, organization:) }
            let!(:settings_multiple) { Decidim::ActionDelegator::Setting.where(id: [setting.id, setting2.id]) }
            let!(:ponderation2) { create(:ponderation, setting: setting2, weight: 1.5) }
            let!(:user2) { create(:user, :confirmed, organization:) }
            let!(:participant2) { create(:participant, setting: setting2, decidim_user: user2, ponderation: ponderation2) }

            subject { described_class.new(relation, settings_multiple) }

            it "includes participants from multiple settings" do
              sql = subject.query.to_sql

              expect(sql).to include(setting.id.to_s)
              expect(sql).to include(setting2.id.to_s)
            end

            context "with votes from different settings" do
              let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
              let!(:vote2) { create(:election_vote, question:, response_option:, voter_uid: user2.to_global_id.to_s) }

              it "connects votes from both settings" do
                result = subject.query

                expect(result.count).to be > 0
              end
            end
          end

          context "with different response options" do
            let!(:response_option2) { question.response_options.second }
            let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
            let!(:vote2) { create(:election_vote, question:, response_option: response_option2, voter_uid: user.to_global_id.to_s) }

            it "handles votes for multiple response options" do
              result = subject.query

              expect(result.count).to eq(question.response_options.count)
            end
          end

          context "with votes from users without participants" do
            let!(:non_participant_user) { create(:user, :confirmed, organization:) }
            let!(:non_participant_vote) { create(:election_vote, question:, response_option:, voter_uid: non_participant_user.to_global_id.to_s) }

            it "still returns all response options" do
              result = subject.query

              expect(result.count).to eq(question.response_options.count)
            end

            it "uses LEFT JOIN so non-participant votes don't break the query" do
              sql = subject.query.to_sql

              expect(sql).to include("LEFT OUTER JOIN")
              expect { subject.query.to_a }.not_to raise_error
            end
          end

          context "with participant without ponderation" do
            let!(:user_no_ponderation) { create(:user, :confirmed, organization:) }
            let!(:participant_no_ponderation) { create(:participant, setting:, decidim_user: user_no_ponderation) }
            let!(:vote_no_ponderation) { create(:election_vote, question:, response_option:, voter_uid: user_no_ponderation.to_global_id.to_s) }

            it "handles participants without ponderations" do
              result = subject.query

              expect(result.count).to be > 0
            end

            it "uses LEFT JOIN for ponderations so missing ponderations don't break query" do
              sql = subject.query.to_sql

              expect(sql).to include("LEFT OUTER JOIN")
              expect { subject.query.to_a }.not_to raise_error
            end
          end
        end

        context "when settings are blank" do
          subject { described_class.new(relation, Decidim::ActionDelegator::Setting.none) }

          it "returns relation.none" do
            result = subject.query

            expect(result).to eq(relation.none)
            expect(result.count).to eq(0)
          end
        end

        context "when relation is empty" do
          let(:empty_relation) { Decidim::Elections::ResponseOption.none }

          subject { described_class.new(empty_relation, settings) }

          it "works with empty relation" do
            result = subject.query

            expect(result.count).to eq(0)
          end
        end

        context "with different organizations" do
          let!(:other_organization) { create(:organization) }
          let!(:other_setting) { create(:setting, organization: other_organization) }
          let!(:other_settings) { Decidim::ActionDelegator::Setting.where(id: other_setting.id) }
          let!(:other_ponderation) { create(:ponderation, setting: other_setting, weight: 3.0) }
          let!(:other_user) { create(:user, :confirmed, organization: other_organization) }
          let!(:other_participant) { create(:participant, setting: other_setting, decidim_user: other_user, ponderation: other_ponderation) }

          subject { described_class.new(relation, other_settings) }

          it "filters participants by organization through settings" do
            sql = subject.query.to_sql

            expect(sql).to include(other_setting.id.to_s)
            expect(sql).not_to include(setting.id.to_s)
          end

          context "with cross-organization votes" do
            let!(:cross_org_vote) { create(:election_vote, question:, response_option:, voter_uid: other_user.to_global_id.to_s) }

            it "only connects participants from the correct organization" do
              result = subject.query

              expect(result.count).to be > 0
            end
          end
        end
      end

      describe "JOIN methods" do
        let!(:ponderation) { create(:ponderation, setting:, weight: 2.0) }
        let!(:user) { create(:user, :confirmed, organization:) }
        let!(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

        describe "#participants_join" do
          it "creates correct Arel OuterJoin node" do
            join_node = subject.send(:participants_join)

            expect(join_node).to be_a(Arel::Nodes::OuterJoin)
          end

          it "includes setting ID filter in join conditions" do
            join_node = subject.send(:participants_join)

            expect(join_node.right.expr.to_sql).to include(setting.id.to_s)
          end

          it "includes CONCAT function for user ID matching" do
            join_node = subject.send(:participants_join)

            expect(join_node.right.expr.to_sql).to include("CONCAT")
          end

          it "matches voter_uid pattern" do
            join_node = subject.send(:participants_join)

            expect(join_node.right.expr.to_sql).to include("voter_uid")
          end
        end

        describe "#ponderations_join" do
          it "creates correct Arel OuterJoin node" do
            join_node = subject.send(:ponderations_join)

            expect(join_node).to be_a(Arel::Nodes::OuterJoin)
          end

          it "joins on ponderation_id" do
            join_node = subject.send(:ponderations_join)

            expect(join_node.right.expr.to_sql).to include("decidim_action_delegator_ponderation_id")
          end
        end
      end
    end
  end
end
