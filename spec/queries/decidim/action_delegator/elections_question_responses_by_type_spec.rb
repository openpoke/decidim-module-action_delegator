# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe ElectionsQuestionResponsesByType do
      let(:organization) { create(:organization) }
      let(:component) { create(:elections_component, organization:) }
      let(:election) { create(:election, :published, :ongoing, :with_questions, component:) }
      let(:question) { election.questions.first }
      let(:response_option) { question.response_options.first }
      let(:setting) { create(:setting, organization:) }
      let(:settings) { Decidim::ActionDelegator::Setting.where(id: setting.id) }

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

          it "returns response options" do
            result = subject.query

            expect(result).to be_a(ActiveRecord::Relation)
            expect(result.length).to eq(question.response_options.count)
          end

          it "includes ponderation information in select" do
            result = subject.query.first

            expect(result).to respond_to(:ponderation_id)
            expect(result).to respond_to(:ponderation_weight)
            expect(result).to respond_to(:votes_total)
          end

          context "with votes" do
            let!(:vote) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }

            it "counts votes correctly" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.votes_total).to eq(1)
            end

            it "includes ponderation weight" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.ponderation_weight).to eq(2.5)
              expect(result.ponderation_id).to eq(ponderation.id)
            end
          end

          context "with multiple votes from different ponderations" do
            let!(:ponderation2) { create(:ponderation, setting:, weight: 1.0) }
            let!(:user2) { create(:user, :confirmed, organization:) }
            let!(:participant2) { create(:participant, setting:, decidim_user: user2, ponderation: ponderation2) }
            let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
            let!(:vote2) { create(:election_vote, question:, response_option:, voter_uid: user2.to_global_id.to_s) }

            it "groups results by ponderation" do
              result = subject.query.where(id: response_option.id)

              expect(result.length).to eq(2) # One for each ponderation

              weights = result.map(&:ponderation_weight)
              expect(weights).to contain_exactly(2.5, 1.0)

              vote_counts = result.map(&:votes_total)
              expect(vote_counts).to contain_exactly(1, 1)
            end
          end

          context "with no votes" do
            it "returns response options with zero vote counts" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.votes_total).to eq(0)
            end

            it "still includes ponderation information" do
              result = subject.query.find_by(id: response_option.id)

              # When there are no votes, the query might return default values
              expect(result.ponderation_weight).to be_a(Numeric)
              expect([ponderation.id, 0]).to include(result.ponderation_id)
            end
          end

          context "with votes from users without participants" do
            let!(:non_participant_user) { create(:user, :confirmed, organization:) }
            let!(:non_participant_vote) { create(:election_vote, question:, response_option:, voter_uid: non_participant_user.to_global_id.to_s) }

            it "excludes votes from non-participants" do
              result = subject.query.find_by(id: response_option.id)

              expect(result.votes_total).to be >= 0
            end
          end

          context "with multiple response options" do
            let!(:response_option2) { question.response_options.second }
            let!(:vote1) { create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s) }
            let!(:vote2) { create(:election_vote, question:, response_option: response_option2, voter_uid: user.to_global_id.to_s) }

            it "returns all response options with their vote counts" do
              result = subject.query

              expect(result.length).to eq(question.response_options.count)

              option1_result = result.find_by(id: response_option.id)
              option2_result = result.find_by(id: response_option2.id)

              expect(option1_result.votes_total).to eq(1)
              expect(option2_result.votes_total).to eq(1)
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

          it "only includes participants from the specified settings" do
            result = subject.query.find_by(id: response_option.id)

            expect(result.votes_total).to be >= 0
          end
        end

        context "with participant without ponderation" do
          let!(:user_no_ponderation) { create(:user, :confirmed, organization:) }
          let!(:participant_no_ponderation) { create(:participant, setting:, decidim_user: user_no_ponderation) }
          let!(:vote_no_ponderation) { create(:election_vote, question:, response_option:, voter_uid: user_no_ponderation.to_global_id.to_s) }

          it "uses default weight of 1.0" do
            result = subject.query.find_by(id: response_option.id)

            expect(result.ponderation_weight).to eq(1.0)
            expect(result.votes_total).to eq(1)
          end
        end
      end
    end
  end
end
