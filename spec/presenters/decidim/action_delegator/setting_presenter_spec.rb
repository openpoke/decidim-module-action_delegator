# frozen_string_literal: true

require "rails_helper"

module Decidim
  module ActionDelegator
    describe SettingPresenter do
      let(:setting) { double("Setting", title:, description:) }
      let(:title) do
        {
          "en" => "Action Delegator",
          "ca" => "Delegador d'Accions"
        }
      end

      let(:description) do
        {
          "en" => "Manage actions and their delegation",
          "ca" => "Gestionar accions i la seva delegació"
        }
      end

      subject { described_class.new(setting) }

      describe "#initialize" do
        it "assigns the setting" do
          expect(subject.instance_variable_get(:@setting)).to eq(setting)
        end
      end

      describe "#title" do
        it "returns the translated title" do
          I18n.with_locale("en") { expect(subject.title).to eq(title["en"]) }
          I18n.with_locale("ca") { expect(subject.title).to eq(title["ca"]) }
        end
      end

      describe "#description" do
        it "returns the translated description" do
          I18n.with_locale("en") { expect(subject.description).to eq(description["en"]) }
          I18n.with_locale("ca") { expect(subject.description).to eq(description["ca"]) }
        end
      end
    end
  end
end
