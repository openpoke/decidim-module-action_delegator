# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::CreateParticipant do
  subject { described_class.new(form) }

  let(:email) { "example@example.org" }
  let(:phone) { "123456789" }
  let(:setting) { create(:setting) }
  let(:invalid) { false }
  let(:ponderation) { create(:ponderation, setting: setting) }

  let(:form) do
    double(
      invalid?: invalid,
      email: email,
      phone: phone,
      decidim_action_delegator_ponderation_id: ponderation.id,
      setting: setting
    )
  end

  it "broadcasts :ok" do
    expect { subject.call }.to broadcast(:ok)
  end

  it "creates a participant" do
    expect { subject.call }.to(change(Decidim::ActionDelegator::Participant, :count).by(1))
  end

  it "creates participant with correct attributes" do
    subject.call
    participant = Decidim::ActionDelegator::Participant.last
    expect(participant.email).to eq(email)
    expect(participant.phone).to eq(phone)
    expect(participant.decidim_action_delegator_ponderation_id).to eq(ponderation.id)
    expect(participant.setting).to eq(setting)
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't create a participant" do
      expect { subject.call }.not_to(change(Decidim::ActionDelegator::Participant, :count))
    end
  end
end
