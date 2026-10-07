# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::UpdateParticipant do
  subject { described_class.new(form, participant) }

  let(:participant) { create(:participant) }
  let(:email) { "example@example.org" }
  let(:phone) { "123456789" }
  let(:setting) { create(:setting) }
  let(:invalid) { false }
  let(:ponderation) { create(:ponderation, setting:) }

  let(:form) do
    double(
      invalid?: invalid,
      email:,
      phone:,
      decidim_action_delegator_ponderation_id: ponderation.id,
      setting:
    )
  end

  it "broadcasts :ok" do
    expect { subject.call }.to broadcast(:ok)
  end

  it "updates a participant" do
    expect { subject.call }.to(change { participant.reload.email }.from(participant.email).to(email))
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't update a participant" do
      expect { subject.call }.not_to(change { participant.reload.email })
    end
  end
end
