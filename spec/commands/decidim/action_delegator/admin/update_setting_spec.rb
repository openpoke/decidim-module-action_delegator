# frozen_string_literal: true

require "spec_helper"

describe Decidim::ActionDelegator::Admin::UpdateSetting do
  subject { described_class.new(form, setting, copy_from_setting) }

  let(:setting) { create(:setting, max_grants: 10, title: { en: "Old Title" }, description: { en: "Old Description" }, active: false) }
  let(:copy_from_setting) { nil }
  let(:max_grants) { 9 }
  let(:authorization_method) { :both }
  let(:title) { { ca: "Nou Títol", es: "Nuevo Título", en: "New Title" } }
  let(:description) { { ca: "Nova Descripció", es: "Nueva Descripción", en: "New Description" } }
  let(:active) { true }
  let(:invalid) { false }

  let(:form) do
    double(
      invalid?: invalid,
      max_grants: max_grants,
      authorization_method: authorization_method,
      title: title,
      description: description,
      active: active
    )
  end

  it "broadcasts :ok" do
    expect { subject.call }.to broadcast(:ok)
  end

  it "updates the setting" do
    expect { subject.call }.to(change { setting.reload.max_grants }.from(10).to(9))
  end

  it "updates all setting attributes" do
    subject.call
    setting.reload
    expect(setting.title).to eq(title.stringify_keys)
    expect(setting.description).to eq(description.stringify_keys)
    expect(setting.active).to be true
    expect(setting.authorization_method).to eq(authorization_method.to_s)
  end

  context "when the form is invalid" do
    let(:invalid) { true }

    it "broadcasts :invalid" do
      expect { subject.call }.to broadcast(:invalid)
    end

    it "doesn't update a Setting" do
      expect { subject.call }.not_to(change { setting.reload.max_grants })
    end
  end

  context "when copy setting" do
    let(:copy_from_setting) { create(:setting, :with_participants, :with_ponderations) }
    let(:form) do
      double(
        invalid?: invalid,
        max_grants: max_grants,
        authorization_method: authorization_method,
        title: title,
        description: description,
        active: active,
        copy_from_setting: copy_from_setting.id
      )
    end

    it "broadcasts :ok" do
      expect { subject.call }.to broadcast(:ok)
    end

    it "updates the setting" do
      expect do
        subject.call
      end.to change {
        setting.reload.participants.count
      }.from(0).to(3).and change {
        setting.reload.ponderations.count
      }.from(0).to(3)
    end
  end
end
