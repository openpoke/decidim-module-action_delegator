# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::UpdatePonderation do
  subject { described_class.new(form, ponderation) }

  let(:ponderation) { create(:ponderation, weight: 1) }
  let(:weight) { 1.5 }
  let(:name) { "My ponderation" }
  let(:setting) { create(:setting) }
  let(:invalid) { false }

  let(:form) do
    double(
      invalid?: invalid,
      weight:,
      name:,
      setting:
    )
  end

  it "broadcasts :ok" do
    expect { subject.call }.to broadcast(:ok)
  end

  it "updates a ponderation" do
    expect { subject.call }.to(change { ponderation.reload.weight }.from(1).to(1.5))
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't update a Ponderation" do
      expect { subject.call }.not_to(change { ponderation.reload.weight })
    end
  end
end
