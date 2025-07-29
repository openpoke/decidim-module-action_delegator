# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::ConsultationDelegations do
  subject { described_class.new(consultation) }

  let(:consultation) { create(:consultation) }
  let(:other_consultation) { create(:consultation, organization: consultation.organization) }
  let(:user) { create(:user, organization: consultation.organization) }
  let(:setting) { create(:setting, consultation: consultation) }
  let(:other_setting) { create(:setting, consultation: other_consultation) }

  let!(:delegation) { create(:delegation, setting: setting, grantee: user) }
  let!(:other_delegation) { create(:delegation, setting: other_setting, grantee: user) }
  let!(:other_user_delegation) { create(:delegation, setting: setting) }

  describe "#query" do
    it "returns delegations of the specified consultation only" do
      expect(subject.query).to contain_exactly(delegation, other_user_delegation)
    end
  end
end
