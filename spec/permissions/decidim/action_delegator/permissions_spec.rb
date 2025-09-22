# frozen_string_literal: true

# require "spec_helper"
#
# describe Decidim::ActionDelegator::Permissions do
#   subject { described_class.new(user, permission_action, context).permissions.allowed? }
#
#   let(:permission_action) { Decidim::PermissionAction.new(**action) }
#   let(:context) { {} }
#
#   let(:organization) { create(:organization, available_authorizations: ["dummy_authorization_workflow"]) }
#   let(:consultation) { create(:consultation, :active, organization: organization) }
#   let(:question) { create(:question, consultation: consultation) }
#   let(:setting) { create(:setting, consultation: consultation) }
#   let(:granter) { create(:user, :confirmed, organization: organization) }
#   let(:user) { create(:user, organization: organization) }
#   let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: user) }
#
#   let(:permissions) { { "vote" => { "authorization_handlers" => { "dummy_authorization_workflow" => {} } } } }
#
#   before do
#     question.build_resource_permission.update!(permissions: permissions)
#   end
#
#   context "when voting a delegation" do
#     let(:action) do
#       { scope: :public, action: :vote_delegation, subject: :question }
#     end
#     let(:context) { { question: question, delegation: delegation } }
#
#     context "and the grantee is verified" do
#       before do
#         create(:authorization, name: "dummy_authorization_workflow", user: user, granted_at: Time.zone.now)
#       end
#
#       context "and it wasn't voted yet" do
#         it { is_expected.to be(true) }
#       end
#
#       context "and it was already voted" do
#         before { create(:vote, author: granter, question: question) }
#
#         it { is_expected.to be(false) }
#       end
#     end
#
#     context "and the grantee is not verified" do
#       it_behaves_like "permission is not set"
#     end
#
#     context "and the user is not the grantee" do
#       let(:other_user) { create(:user, organization: organization) }
#       let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: other_user) }
#
#       before do
#         Decidim::Authorization.create!(name: "dummy_authorization_workflow", decidim_user_id: other_user.id, granted_at: Time.zone.now)
#       end
#
#       it { is_expected.to be(false) }
#     end
#   end
#
#   context "when unvoting a delegation" do
#     let(:action) do
#       { scope: :public, action: :unvote_delegation, subject: :question }
#     end
#     let(:context) { { question: question, delegation: delegation } }
#
#     let!(:vote) { create(:vote, author: granter, question: question) }
#
#     context "when the grantee is verified" do
#       before do
#         create(:authorization, name: "dummy_authorization_workflow", user: user, granted_at: Time.zone.now)
#       end
#
#       context "and it was already voted" do
#         it { is_expected.to be(true) }
#       end
#
#       context "and it wasn't voted yet" do
#         before { vote.destroy }
#
#         it { is_expected.to be(false) }
#       end
#     end
#
#     context "when the grantee is not verified" do
#       it_behaves_like "permission is not set"
#     end
#
#     context "when the user is not the grantee" do
#       let(:other_user) { create(:user, organization: organization) }
#       let(:delegation) { create(:delegation, setting: setting, granter: granter, grantee: other_user) }
#
#       before do
#         Decidim::Authorization.create!(name: "dummy_authorization_workflow", decidim_user_id: other_user.id, granted_at: Time.zone.now)
#       end
#
#       it { is_expected.to be(false) }
#     end
#   end
# end
