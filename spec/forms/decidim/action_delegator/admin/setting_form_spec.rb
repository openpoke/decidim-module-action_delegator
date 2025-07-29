# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::SettingForm do
  subject { described_class.from_params(attributes).with_context(context) }

  let(:organization) { create(:organization) }
  let(:attributes) do
    {
      title:,
      description:,
      max_grants: 5,
      authorization_method: authorization_method
    }
  end
  let(:title) { { ca: "Títol", es: "Título", en: "Title" } }
  let(:description) { { ca: "Descripció", es: "Descripción", en: "Description" } }

  let(:authorization_method) { :both }
  let(:context) { { current_organization: organization } }

  it { is_expected.to be_valid }

  context "when title is missing" do
    let(:title) { { ca: "", es: "", en: "" } }

    it { is_expected.to be_invalid }
  end

  context "when max_grants is missing" do
    let(:attributes) { super().except(:max_grants) }

    it { is_expected.to be_invalid }
  end
end
