# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::CreateSetting do
  subject { described_class.new(form, copy_from_setting) }

  let(:organization) { create(:organization) }
  let(:max_grants) { 10 }
  let(:copy_from_setting) { nil }
  let(:authorization_method) { :both }
  let(:title) { { ca: "Títol", es: "Título", en: "Title" } }
  let(:description) { { ca: "Descripció", es: "Descripción", en: "Description" } }
  let(:active) { true }
  let(:invalid) { false }

  let(:form) do
    double(
      invalid?: invalid,
      max_grants: max_grants,
      authorization_method: authorization_method,
      title: title,
      description: description,
      active: active,
      context: double(current_organization: organization)
    )
  end

  it "broadcasts :ok" do
    expect { subject.call }.to broadcast(:ok)
  end

  it "creates a setting" do
    expect { subject.call }.to(change(Decidim::ActionDelegator::Setting, :count).by(1))
  end

  it "creates setting with correct attributes" do
    subject.call
    setting = Decidim::ActionDelegator::Setting.last
    expect(setting.title).to eq(title.stringify_keys)
    expect(setting.description).to eq(description.stringify_keys)
    expect(setting.max_grants).to eq(max_grants)
    expect(setting.authorization_method).to eq(authorization_method.to_s)
    expect(setting.active).to eq(active)
    expect(setting.organization).to eq(organization)
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't create a setting" do
      expect { subject.call }.not_to(change(Decidim::ActionDelegator::Setting, :count))
    end
  end

  context "when copy setting" do
    let!(:copy_from_setting) { create(:setting, :with_participants, :with_ponderations, title: { en: "Copy Title" }, description: { en: "Copy Description" }, organization:) }
    let(:form) do
      double(
        invalid?: invalid,
        max_grants: max_grants,
        authorization_method: authorization_method,
        title: title,
        description: description,
        active: active,
        context: double(current_organization: organization),
        copy_from_setting: copy_from_setting.id
      )
    end

    it "broadcasts :ok" do
      expect { subject.call }.to broadcast(:ok)
    end

    it "creates a setting" do
      expect { subject.call }.to(change(Decidim::ActionDelegator::Setting, :count).by(1))
    end

    it "copies participants" do
      expect { subject.call }.to(change(Decidim::ActionDelegator::Participant, :count).by(copy_from_setting.participants.count))
    end

    it "copies ponderations" do
      expect { subject.call }.to(change(Decidim::ActionDelegator::Ponderation, :count).by(copy_from_setting.ponderations.count))
    end
  end
end
