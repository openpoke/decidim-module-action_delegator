# frozen_string_literal: true

# require "spec_helper"
#
# module Decidim::ActionDelegator::Verifications
#   describe DelegationsVerifierForm do
#     subject { described_class.from_params(attributes).with_context(context) }
#
#     let(:context) do
#       {
#         current_user: user,
#         setting: setting
#       }
#     end
#     let(:organization) { create(:organization, available_authorizations: %w(delegations_verifier)) }
#     let(:user) { create(:user, organization: organization) }
#     let(:consultation) { create(:consultation, organization: organization) }
#     let(:setting) { create(:setting, consultation: consultation, authorization_method: authorization_method) }
#     let(:authorization_method) { :both }
#     let(:attributes) do
#       {
#         email: email,
#         phone: phone
#       }
#     end
#     let(:email) { user.email }
#     let(:phone) { "123456" }
#
#     it { is_expected.to be_invalid }
#
#     context "when method is email" do
#       let(:authorization_method) { :email }
#
#       it { is_expected.to be_invalid }
#     end
#
#     context "when there's a participant" do
#       let!(:participant) { create(:participant, setting: setting, email: email, phone: phone) }
#
#       it { is_expected.to be_valid }
#
#       context "when method is email" do
#         let(:authorization_method) { :email }
#         let(:phone) { "" }
#
#         it { is_expected.to be_valid }
#       end
#
#       context "when method is phone" do
#         let(:authorization_method) { :phone }
#         let(:email) { "" }
#
#         it { is_expected.to be_valid }
#
#         context "when different phone prefixes in the participant" do
#           ["", "+34", "0034", "34"].each do |prefix|
#             let(:phone) { "#{prefix}34123456" }
#
#             it { is_expected.to be_valid }
#           end
#         end
#
#         context "when different phone prefixes in the attributes" do
#           ["", "+34", "0034", "34"].each do |prefix|
#             let(:attributes) do
#               {
#                 phone: "#{prefix}#{phone}"
#               }
#             end
#
#             it { is_expected.to be_valid }
#           end
#         end
#       end
#
#       context "when no setting" do
#         let(:context) do
#           {
#             current_user: user,
#             setting: nil
#           }
#         end
#
#         it { is_expected.to be_invalid }
#       end
#     end
#   end
# end
