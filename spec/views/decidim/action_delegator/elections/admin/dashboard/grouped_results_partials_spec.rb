# frozen_string_literal: true

require "spec_helper"

describe "Grouped admin results partials" do # rubocop:disable RSpec/DescribeClass
  let(:route_helper) do
    instance_double(
      "RouteHelper",
      elections_admin_results_by_type_and_weight_path: "/by_type_and_weight",
      elections_admin_results_sum_of_weights_path: "/sum_of_weights"
    )
  end

  let(:election) { instance_double("Election", per_question?: false) }
  let(:question_body) { { "en" => "Question body" } }
  let(:question) do
    instance_double(
      "Question",
      id: 101,
      body: question_body,
      question_type: "single_option",
      grouped?: grouped
    )
  end

  before do
    allow(view).to receive(:decidim_action_delegator).and_return(route_helper)
    allow(view).to receive(:translated_attribute) { |value| value.is_a?(Hash) ? value["en"] : value }
  end

  describe "decidim/action_delegator/elections/admin/dashboard/_by_type_and_weight" do
    let(:grouped) { true }

    let(:group_a) { instance_double("ResponseGroup", title: { "en" => "Group A" }) }
    let(:group_b) { instance_double("ResponseGroup", title: { "en" => "Group B" }) }

    let(:option_one) { instance_double("ResponseOption", id: 11) }
    let(:option_two) { instance_double("ResponseOption", id: 12) }
    let(:option_three) { instance_double("ResponseOption", id: 13) }

    let(:responses_by_type) do
      [
        {
          id: 11,
          body: { "en" => "Option 1" },
          ponderation_id: 1,
          ponderation_title: "Basic (x1.0)",
          votes_count_text: "2 votes",
          votes_percent_text: "50.0%"
        },
        {
          id: 12,
          body: { "en" => "Option 2" },
          ponderation_id: 2,
          ponderation_title: "High (x2.0)",
          votes_count_text: "1 vote",
          votes_percent_text: "25.0%"
        },
        {
          id: 999,
          body: { "en" => "Filtered option" },
          ponderation_id: nil,
          ponderation_title: "-",
          votes_count_text: "0 votes",
          votes_percent_text: "0.0%"
        }
      ]
    end

    before do
      allow(view).to receive(:elections_question_responses_by_type).with(question).and_return(responses_by_type)
      allow(view).to receive(:grouped_response_options).with(question).and_return(
        {
          group_a => [option_one, option_two],
          group_b => [option_three]
        }
      )

      render partial: "decidim/action_delegator/elections/admin/dashboard/by_type_and_weight",
             locals: { election: election, election_questions: [question] }
    end

    it "renders grouped headers and options included in the groups" do
      expect(rendered).to include("Group A")
      expect(rendered).to include("Group B")
      expect(rendered).to include("Option 1")
      expect(rendered).to include("Option 2")
    end

    it "does not render options that are not in any grouped response list" do
      expect(rendered).not_to include("Filtered option")
    end
  end

  describe "decidim/action_delegator/elections/admin/dashboard/_sum_of_weights" do
    let(:grouped) { false }

    let(:responses_by_weight) do
      [
        {
          id: 21,
          body: { "en" => "Option A" },
          votes_count_text: "3",
          votes_percent_text: "60.0%"
        },
        {
          id: 22,
          body: { "en" => "Option B" },
          votes_count_text: "2",
          votes_percent_text: "40.0%"
        }
      ]
    end

    before do
      allow(view).to receive(:elections_question_weighted_responses).with(question).and_return(responses_by_weight)

      render partial: "decidim/action_delegator/elections/admin/dashboard/sum_of_weights",
             locals: { election: election, election_questions: [question] }
    end

    it "renders options normally when question is not grouped" do
      expect(rendered).to include("Option A")
      expect(rendered).to include("Option B")
      expect(rendered).to include("60.0%")
      expect(rendered).to include("40.0%")
    end

    it "does not render a grouped header row" do
      fragment = Nokogiri::HTML.fragment(rendered)

      expect(fragment.css("tbody tr").size).to eq(responses_by_weight.size)
    end
  end
end
