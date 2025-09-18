# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::SettingsHelper do
  subject { helper }

  let(:organization) { create(:organization) }
  let(:component) { create(:elections_component, organization:) }
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
              "setting" => setting.id
            }
          }
        }
      }
    )
  end
  let(:user) { create(:user, :confirmed, organization:) }
  let(:setting) { create(:setting, organization:) }

  describe "#settings_for" do
    subject { helper.settings_for(resource) }

    context "when resource is an Election" do
      let(:resource) { election }

      it "returns ElectionSettings query" do
        expect(subject).to be_a(ActiveRecord::Relation)
        expect(subject.to_sql).to include("decidim_action_delegator_settings")
        expect(subject.count).to eq(1)
        expect(subject.first).to eq(setting)
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization:) }

      it "returns Setting.none" do
        expect(subject).to eq(Decidim::ActionDelegator::Setting.none)
        expect(subject.count).to eq(0)
      end
    end
  end

  describe "#delegations_for" do
    subject { helper.delegations_for(resource, user) }

    context "when resource is an Election" do
      let(:resource) { election }
      let!(:delegation) { create(:delegation, setting: setting, grantee: user) }
      let!(:other_delegation) { create(:delegation, setting: setting) }

      it "returns delegations for the user as grantee" do
        expect(subject).to be_a(ActiveRecord::Relation)
        expect(subject.count).to eq(1)
        expect(subject.first).to eq(delegation)
        expect(subject.first.grantee).to eq(user)
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization:) }

      it "returns Delegation.none" do
        expect(subject).to eq(Decidim::ActionDelegator::Delegation.none)
        expect(subject.count).to eq(0)
      end
    end
  end

  describe "#participant_voted?" do
    subject { helper.participant_voted?(resource, user) }

    context "when resource is an Election" do
      let(:resource) { election }
      let!(:question) { create(:election_question, :with_response_options, election:) }

      context "when user has voted" do
        before do
          create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: user.to_global_id.to_s)
        end

        it { is_expected.to be true }
      end

      context "when user has not voted" do
        it { is_expected.to be false }
      end

      context "when user has voted with different voter_uid format" do
        before do
          create(:election_vote, question: question, response_option: question.response_options.first, voter_uid: "different-uid")
        end

        it { is_expected.to be false }
      end
    end

    context "when resource is not an Election" do
      let(:resource) { create(:user, organization:) }

      it { is_expected.to be false }
    end
  end

  describe "#elections_question_responses_by_type" do
    let(:question) { create(:election_question, :with_response_options, election:) }
    let(:response_option) { question.response_options.first }
    let(:ponderation) { create(:ponderation, setting:, weight: 2.5) }
    let(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

    before do
      allow(helper).to receive(:current_resource_settings).and_return(Decidim::ActionDelegator::Setting.where(id: setting.id))
    end

    context "when there are votes" do
      before do
        create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s)
      end

      it "returns response options with vote statistics" do
        result = helper.elections_question_responses_by_type(question)

        expect(result).to be_an(Array)
        expect(result).not_to be_empty

        option_data = result.first
        expect(option_data).to include(:id, :body, :votes_count, :votes_count_text, :votes_percent, :votes_percent_text)
        expect(option_data[:id]).to be_a(Integer)
        expect(option_data[:votes_count]).to be_a(Integer)
        expect(option_data[:votes_percent]).to be_a(Numeric)
      end

      it "includes ponderation information" do
        result = helper.elections_question_responses_by_type(question)
        option_data = result.first

        expect(option_data).to include(:ponderation_id, :ponderation_title)
      end

      it "calculates vote percentages correctly" do
        result = helper.elections_question_responses_by_type(question)
        option_data = result.first

        expect(option_data[:votes_percent]).to be > 0
        expect(option_data[:votes_percent_text]).to match(/\d+\.\d%/)
      end
    end

    context "when there are no votes" do
      it "returns response options with zero statistics" do
        result = helper.elections_question_responses_by_type(question)

        expect(result).to be_an(Array)
        option_data = result.first
        expect(option_data[:votes_count]).to eq(0)
        expect(option_data[:votes_percent]).to eq(0)
      end
    end
  end

  describe "#elections_question_weighted_responses" do
    let(:question) { create(:election_question, :with_response_options, election:) }
    let(:response_option) { question.response_options.first }
    let(:ponderation) { create(:ponderation, setting:, weight: 3.0) }
    let(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }

    before do
      allow(helper).to receive(:current_resource_settings).and_return(Decidim::ActionDelegator::Setting.where(id: setting.id))
    end

    context "when there are weighted votes" do
      before do
        create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s)
      end

      it "returns weighted response options" do
        result = helper.elections_question_weighted_responses(question)

        expect(result).to be_an(Array)
        expect(result).not_to be_empty

        option_data = result.first
        expect(option_data).to include(:id, :question_id, :body, :votes_count, :votes_count_text, :votes_percent, :votes_percent_text)
        expect(option_data[:question_id]).to eq(question.id)
      end

      it "includes weighted vote counts" do
        result = helper.elections_question_weighted_responses(question)
        option_data = result.first

        expect(option_data[:votes_count]).to be_a(Numeric)
        expect(option_data[:votes_percent]).to be_a(Numeric)
      end

      it "calculates weighted percentages" do
        result = helper.elections_question_weighted_responses(question)
        option_data = result.first

        expect(option_data[:votes_percent]).to be >= 0
        expect(option_data[:votes_percent_text]).to match(/\d+\.\d%/)
      end
    end

    context "when there are no votes" do
      it "returns response options with zero weighted statistics" do
        result = helper.elections_question_weighted_responses(question)

        expect(result).to be_an(Array)
        option_data = result.first
        expect(option_data[:votes_count]).to eq(0)
        expect(option_data[:votes_percent]).to eq(0)
      end
    end
  end

  describe "#elections_question_stats" do
    let(:question) { create(:election_question, :with_response_options, election:) }
    let(:response_option) { question.response_options.first }
    let(:ponderation) { create(:ponderation, setting:, weight: 4.0) }
    let(:participant) { create(:participant, setting:, decidim_user: user, ponderation:) }
    let(:delegatee_user) { create(:user, :confirmed, organization:) }
    let(:delegatee_participant) { create(:participant, setting:, decidim_user: delegatee_user, ponderation:) }
    let(:delegation) { create(:delegation, setting:, granter: user, grantee: delegatee_user) }

    before do
      allow(helper).to receive(:current_resource_settings).and_return(Decidim::ActionDelegator::Setting.where(id: setting.id))
    end

    context "with regular votes" do
      before do
        create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s)
      end

      it "returns comprehensive vote statistics" do
        result = helper.elections_question_stats(question)

        expect(result).to include(:participants, :participants_text, :unweighted_votes, :unweighted_votes_text, :weighted_votes, :weighted_votes_text, :delegated_votes, :delegated_votes_text)
        expect(result[:participants]).to eq(1)
        expect(result[:unweighted_votes]).to eq(1)
        expect(result[:weighted_votes]).to be_a(Integer)
        expect(result[:delegated_votes]).to eq(0)
      end

      it "includes properly formatted text fields" do
        result = helper.elections_question_stats(question)

        expect(result[:participants_text]).to be_a(String)
        expect(result[:unweighted_votes_text]).to be_a(String)
        expect(result[:weighted_votes_text]).to be_a(String)
        expect(result[:delegated_votes_text]).to be_a(String)
      end
    end

    context "with delegated votes" do
      let!(:delegated_vote) do
        create(:election_vote, question:, response_option:, voter_uid: delegatee_user.to_global_id.to_s).tap do |vote|
          vote.versions.create!(
            decidim_action_delegator_delegation_id: delegation.id,
            item_type: vote.class.name,
            item_id: vote.id,
            event: "create"
          )
        end
      end

      it "counts delegated votes correctly" do
        result = helper.elections_question_stats(question)

        expect(result[:participants]).to eq(1)
        expect(result[:unweighted_votes]).to eq(1)
        expect(result[:delegated_votes]).to eq(1)
      end
    end

    context "with multiple participants" do
      let(:user2) { create(:user, :confirmed, organization:) }
      let(:participant2) { create(:participant, setting:, decidim_user: user2, ponderation:) }

      before do
        create(:election_vote, question:, response_option:, voter_uid: user.to_global_id.to_s)
        create(:election_vote, question: question, response_option: response_option, voter_uid: user2.to_global_id.to_s)
      end

      it "counts multiple participants correctly" do
        result = helper.elections_question_stats(question)

        expect(result[:participants]).to eq(2)
        expect(result[:unweighted_votes]).to eq(2)
        expect(result[:weighted_votes]).to be > 0
      end
    end

    context "when there are no votes" do
      it "returns zero statistics" do
        result = helper.elections_question_stats(question)

        expect(result[:participants]).to eq(0)
        expect(result[:unweighted_votes]).to eq(0)
        expect(result[:weighted_votes]).to eq(0)
        expect(result[:delegated_votes]).to eq(0)
      end
    end
  end
end
