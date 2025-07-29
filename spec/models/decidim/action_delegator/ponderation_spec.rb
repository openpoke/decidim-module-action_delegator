# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Ponderation do
      subject { build(:ponderation) }

      it { is_expected.to be_valid }
      it { is_expected.to belong_to(:setting) }
      it { is_expected.to have_many(:participants).dependent(:restrict_with_error) }

      it "has an automatic title" do
        expect(subject.title).to eq("#{subject.name} (x#{subject.weight})")
      end

      it "can be destroyed" do
        subject.save!
        expect { subject.destroy }.to change(Ponderation, :count).by(-1)
      end

      context "when has participants" do
        before do
          create(:participant, ponderation: subject)
        end

        it "does not destroy" do
          expect { subject.destroy }.not_to change(Ponderation, :count)
        end
      end
    end
  end
end
