# frozen_string_literal: true

# # frozen_string_literal: true
#
# require "spec_helper"
#
# describe Decidim::ActionDelegator::Admin::FixResourcePermissions do
#   subject { described_class.new(resources) }
#
#   let(:organization) { create(:organization, available_authorizations: ["delegations_verifier"]) }
#   let(:consultation) { create(:consultation, organization: organization) }
#   let!(:question) { create(:question, consultation: consultation) }
#   let(:resources) { consultation.questions }
#
#   it "broadcasts :ok" do
#     expect { subject.call }.to broadcast(:ok)
#   end
#
#   it "adds delegations_verifier authorization handler to resource permissions" do
#     expect(question.permissions).to be_nil
#     subject.call
#     expect(question.reload.permissions["vote"]["authorization_handlers"]["delegations_verifier"]).to eq({})
#   end
#
#   context "when permissions already exist" do
#     before do
#       question.build_resource_permission
#       question.resource_permission.permissions = { "comment" => { "authorization_handlers" => { "another_handler" => { "foo" => "bar" } } } }
#       question.save!
#     end
#
#     it "adds delegations_verifier authorization handler to resource permissions" do
#       subject.call
#       expect(question.reload.permissions).to eq({
#                                                   "comment" => { "authorization_handlers" =>
#                                                     {
#                                                       "another_handler" => { "foo" => "bar" },
#                                                       "delegations_verifier" => {}
#                                                     } },
#                                                   "vote" => { "authorization_handlers" =>
#                                                     {
#                                                       "delegations_verifier" => {}
#                                                     } }
#                                                 })
#     end
#   end
#
#   context "when no resources" do
#     let(:resources) { nil }
#
#     it "broadcasts :invalid" do
#       expect { subject.call }.to broadcast(:invalid)
#     end
#   end
#
#   context "when save fails" do
#     before do
#       allow_any_instance_of(Decidim::ResourcePermission).to receive(:save).and_return(false)
#     end
#
#     it "broadcasts :invalid" do
#       expect { subject.call }.to broadcast(:invalid)
#     end
#   end
# end
