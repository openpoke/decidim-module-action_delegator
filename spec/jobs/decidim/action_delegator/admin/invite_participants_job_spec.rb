# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::InviteParticipantsJob do
  let(:organization) { create(:organization) }
  let(:current_setting) { create(:setting, organization:, authorization_method:) }
  let(:authorization_method) { "both" }
  let!(:participants) { create_list(:participant, 3, setting: current_setting) }

  it "does not raise error" do
    expect do
      described_class.perform_later(current_setting, organization)
    end.not_to raise_error
  end

  it "sends an email to the invited participant" do
    perform_enqueued_jobs do
      described_class.perform_later(current_setting, organization)
    end

    email = last_email
    expect(email.subject).to include("Invitation instructions")
    expect(email.body.encoded).to match("Accept invitation")
  end

  context "when participants are registered" do
    let(:user) { create(:user, organization:) }
    let(:participant) { create(:participant, setting: current_setting, decidim_user_id: user.id) }

    it "does not send invitiations" do
      expect { described_class.perform_later(current_setting, organization) }.not_to raise_error

      expect(last_email).to be_nil
    end
  end
end
