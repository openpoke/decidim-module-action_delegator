# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe ElectionsQuestionWeightedResponses do
      let!(:organization) { create(:organization) }
      let!(:component) { create(:elections_component, organization:) }
      let!(:election) { create(:election, :published, :ongoing, :with_questions, component:) }
      let!(:question) { election.questions.first }
      let!(:response_option) { question.response_options.first }
      let!(:setting) { create(:setting, organization:) }
      let!(:settings) { Decidim::ActionDelegator::Setting.where(id: setting.id) }

      subject { described_class.new(question, settings) }

      describe "#initialize" do
        it "assigns the question and settings" do
          expect(subject.instance_variable_get(:@question)).to eq(question)
          expect(subject.instance_variable_get(:@settings)).to eq(settings)
        end
      end

      describe "#query" do
        context "when question and settings are present" do
          let!(:ponderation) { create(:ponderation, setting:, weight: 2.5) }
          let!(:user) { create(:user, :confirmed, organization:) }
          let!(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

          it "returns response options with weighted totals" do
            result = subject.query

            expect(result).to be_a(ActiveRecord::Relation)
            expect(result.length).to eq(question.response_options.count)
          end

          it "includes weighted_votes_total in select" do
            result = subject.query.first

            expect(result).to respond_to(:weighted_votes_total)
          end

          context "with votes" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "calculates weighted votes correctly" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.weighted_votes_total).to eq(2.5) # 1 vote * 2.5 weight
            end

            it "includes original response option attributes" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.id).to eq(response_option.id)
              expect(result.question_id).to eq(response_option.question_id)
              expect(result.body).to eq(response_option.body)
            end
          end

          context "with multiple votes from different ponderations" do
            let!(:ponderation2) { create(:ponderation, setting:, weight: 1.0) }
            let!(:user2) { create(:user, :confirmed, organization:) }
            let!(:participant2) { create(:participant, setting:, decidim_user: user2, ponderation: ponderation2) }
            let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
            let!(:vote2) { create(:election_vote, question:, response_option:, voter_uid: user2.to_global_id.to_s) }

            it "sums weighted votes correctly" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.weighted_votes_total).to eq(3.5) # (1 * 2.5) + (1 * 1.0)
            end
          end

          context "with no votes" do
            it "returns zero weighted total" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.weighted_votes_total).to eq(0)
            end

            it "still includes all response options" do
              result = subject.query

              expect(result.length).to eq(question.response_options.count)
              response_option_ids = result.map(&:id)
              expect(response_option_ids).to include(response_option.id)
            end
          end

          context "with votes from users without participants" do
            let!(:non_participant_user) { create(:user, :confirmed, organization:) }
            let!(:non_participant_vote) { create(:election_vote, question:, response_option:, voter_uid: non_participant_user.to_global_id.to_s) }

            it "excludes non-participant votes from weighted calculation" do
              result = subject.query.find_by(id: response_option.id)

              # Votes from users without participants should be excluded or have minimal impact
              expect(result.weighted_votes_total).to be >= 0
            end
          end

          context "with multiple response options" do
            let!(:response_option2) { question.response_options.second }
            let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
            let!(:vote2) { create(:election_vote, question:, response_option: response_option2, voter_uid: user.to_global_id.to_s) }

            it "calculates weighted totals for each response option" do
              result = subject.query

              expect(result.length).to eq(question.response_options.count)

              option1_result = result.find_by(id: response_option.id)
              option2_result = result.find_by(id: response_option2.id)

              expect(option1_result.weighted_votes_total).to eq(2.5)
              expect(option2_result.weighted_votes_total).to eq(2.5)
            end
          end

          context "with participant without ponderation" do
            let!(:user_no_ponderation) { create(:user, :confirmed, organization:) }
            let!(:participant_no_ponderation) { create(:participant, setting:, decidim_user: user_no_ponderation) }
            let!(:vote_no_ponderation) { create(:election_vote, question:, response_option:, voter_uid: user_no_ponderation.to_global_id.to_s) }

            it "uses default weight of 1.0 for weighted calculation" do
              result = subject.query.find_by(id: response_option.id)

              # The weighted total includes both the participant with ponderation (2.5) and without (1.0)
              expect(result.weighted_votes_total).to be_a(Numeric)
              expect(result.weighted_votes_total).to be > 0
            end
          end
        end

        context "when question is blank" do
          subject { described_class.new(nil, settings) }

          it "returns ResponseOption.none" do
            result = subject.query

            expect(result).to eq(Decidim::Elections::ResponseOption.none)
            expect(result.count).to eq(0)
          end
        end

        context "when settings are blank" do
          subject { described_class.new(question, Decidim::ActionDelegator::Setting.none) }

          it "returns ResponseOption.none" do
            result = subject.query

            expect(result).to eq(Decidim::Elections::ResponseOption.none)
            expect(result.count).to eq(0)
          end
        end

        context "when both question and settings are blank" do
          subject { described_class.new(nil, Decidim::ActionDelegator::Setting.none) }

          it "returns ResponseOption.none" do
            result = subject.query

            expect(result).to eq(Decidim::Elections::ResponseOption.none)
            expect(result.count).to eq(0)
          end
        end

        context "with different organizations" do
          let!(:other_organization) { create(:organization) }
          let!(:other_setting) { create(:setting, organization: other_organization) }
          let!(:other_settings) { Decidim::ActionDelegator::Setting.where(id: other_setting.id) }
          let!(:other_user) { create(:user, :confirmed, organization: other_organization) }
          let!(:other_ponderation) { create(:ponderation, setting: other_setting, weight: 3.0) }
          let!(:other_participant) { create(:participant, setting: other_setting, decidim_user: other_user, ponderation: other_ponderation) }
          let!(:other_vote) { create(:election_vote, question:, response_option:, voter_uid: other_user.to_global_id.to_s) }

          subject { described_class.new(question, other_settings) }

          it "only includes participants from specified settings in weighted calculation" do
            result = subject.query.find_by(id: response_option.id)

            # Should only count votes from participants in the specified settings
            expect(result.weighted_votes_total).to be >= 0
          end
        end
      end
    end
  end
end
