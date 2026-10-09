# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::CreatePonderation do
  subject { described_class.new(form) }

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

  it "creates a ponderation" do
    expect { subject.call }.to(change(Decidim::ActionDelegator::Ponderation, :count).by(1))
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't create a Ponderation" do
      expect { subject.call }.not_to(change(Decidim::ActionDelegator::Ponderation, :count))
    end
  end
end
