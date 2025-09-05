# frozen_string_literal: true

# # frozen_string_literal: true

# require "spec_helper"

# module Decidim::ActionDelegator
#   describe ConsultationResultsSerializer do
#     subject { described_class.new(result) }

#     let(:question) { instance_double(Decidim::Consultations::Question, title: { "ca" => "question_title" }) }
#     let(:result) do
#       double(
#         :result,
#         title: { "ca" => "A" },
#         membership_type: "consumer",
#         membership_weight: 2,
#         votes_count: 2,
#         question: question
#       )
#     end

#     describe "#serialize" do
#       it "includes all attributes" do
#         expect(subject.serialize).to eq(
#           question: "question_title",
#           response: "A",
#           membership_type: "consumer",
#           votes_count: 2,
#           membership_weight: 2
#         )
#       end
#     end
#   end
# end
