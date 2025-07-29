# frozen_string_literal: true

require "spec_helper"

module Decidim
  module ActionDelegator
    describe Participant do
      subject { build(:participant, ponderation: ponderation, email: email, phone: phone, setting: setting, decidim_user: decidim_user) }

      let(:setting) { create(:setting, authorization_method: authorization_method) }
      let(:organization) { setting.organization }
      let(:authorization_method) { :email }
      let(:ponderation) { create(:ponderation) }
      let(:user) { create(:user, organization: setting.organization, last_sign_in_at: Time.zone.parse("2023-01-01")) }
      let(:email) { user.email }
      let(:phone) { "34123456" }
      let(:decidim_user) { nil }

      it { is_expected.to be_valid }
      it { is_expected.to belong_to(:setting) }

      context "when user belongs to a different organization" do
        let(:decidim_user) { create(:user) }

        it { is_expected.not_to be_valid }
      end

      it "belong_to a ponderation" do
        expect(subject.ponderation).to eq(ponderation)
      end

      it "has a related user" do
        expect(subject.user).to eq(user)
        expect(subject.user_from_metadata).to eq(user)
        expect(subject.decidim_user).to be_nil
        expect(subject.user_name).to eq(user.name)
        expect(subject.last_login).to eq(user.last_sign_in_at)
        expect(subject.ponderation_title).to eq(ponderation.title)
      end

      it "sets the decidim_user on save" do
        subject.save
        expect(subject.reload.decidim_user).to eq(user)
      end

      shared_examples "hasn't voted" do
        it "reports as not voted" do
          expect(subject).not_to be_voted
        end

        it "can be destroyed" do
          subject.save
          expect { subject.destroy }.to change(Participant, :count).by(-1)
        end
      end

      shared_examples "has voted" do
        it "reports as voted" do
          expect(subject).to be_voted
        end

        it "cannot be destroyed" do
          subject.save
          expect { subject.destroy }.not_to change(Participant, :count)
        end
      end

      it_behaves_like "hasn't voted"

      context "when user has voted in the setting's consultation" do
        let!(:vote) { create(:vote, response: response, question: question, author: user) }
        let(:response) { create(:response, question: question) }
        let(:question) { create(:question, consultation: setting.consultation) }

        it_behaves_like "has voted"

        context "and voted in another consultation" do
          let(:other_consultation) { create(:consultation, organization: setting.consultation.organization) }
          let(:other_question) { create(:question, consultation: other_consultation) }
          let(:other_response) { create(:response, question: other_question) }
          let!(:vote) { create(:vote, response: other_response, question: other_question, author: user) }

          it_behaves_like "hasn't voted"
        end
      end

      context "when same email exists in another organization" do
        let!(:existing_user) { create(:user) }
        let(:email) { existing_user.email }

        it "does not set the decidim_user on save" do
          subject.save
          expect(subject.reload.decidim_user).to be_nil
        end
      end

      context "when creating a new user" do
        let(:new_user) { create(:participant, email: email, setting: setting) }

        it "sets the decidim_user on creation" do
          expect(new_user.decidim_user).to eq(user)
        end
      end

      context "when decidim_user is set" do
        let(:decidim_user) { user }

        it "has a related user" do
          expect(subject.user).to eq(user)
          expect(subject.user_from_metadata).to eq(user)
          expect(subject.decidim_user).to eq(user)
          expect(subject.user_name).to eq(user.name)
        end

        context "when decidim_user is not the same as user_from_metadata" do
          let(:decidim_user) { create(:user) }

          it "has a related user" do
            expect(subject.user).to eq(decidim_user)
            expect(subject.user_from_metadata).to eq(user)
            expect(subject.decidim_user).to eq(decidim_user)
            expect(subject.user_name).to eq(decidim_user.name)
          end
        end
      end

      context "when email already exists" do
        let(:existing_setting) { setting }
        let(:existing_email) { email }
        let!(:existing_participant) { create(:participant, email: existing_email, setting: existing_setting) }

        it { is_expected.not_to be_valid }

        context "and setting is different" do
          let(:consultation) { create(:consultation, organization: organization) }
          let(:existing_setting) { create(:setting, consultation: consultation) }

          it { is_expected.to be_valid }
        end
      end

      context "when a decidim_user is already assigned to a participant" do
        let(:decidim_user) { user }
        let(:existing_setting) { setting }
        let!(:existing_participant) { create(:participant, setting: existing_setting, decidim_user: user) }

        it { is_expected.not_to be_valid }

        context "and setting is different" do
          let(:consultation) { create(:consultation, organization: organization) }
          let(:existing_setting) { create(:setting, consultation: consultation) }

          it { is_expected.to be_valid }
        end
      end

      context "when verification method is phone" do
        let(:authorization_method) { :phone }
        let(:email) { "" }

        it { is_expected.to be_valid }

        it "has no user" do
          expect(subject.user).to be_nil
          expect(subject.decidim_user).to be_nil
        end

        context "when phone already exists" do
          let(:existing_setting) { setting }
          let(:existing_phone) { phone }
          let!(:existing_participant) { create(:participant, phone: existing_phone, setting: existing_setting) }

          it { is_expected.not_to be_valid }

          context "and setting is different" do
            let(:consultation) { create(:consultation, organization: organization) }
            let(:existing_setting) { create(:setting, consultation: consultation) }

            it { is_expected.to be_valid }
          end
        end

        context "and an authorization exists" do
          let(:user_phone) { phone }
          let!(:authorization) { create(:authorization, user: user, name: "delegations_verifier", metadata: { phone: user_phone }, unique_id: uniq_id) }
          let(:uniq_id) { Digest::MD5.hexdigest("#{user_phone}-#{user.organization.id}-#{Digest::MD5.hexdigest(Rails.application.secrets.secret_key_base)}") }

          it "has a related user" do
            expect(subject.user).to eq(user)
            expect(subject.decidim_user).to be_nil
            expect(subject.user_from_metadata).to eq(user)
            expect(subject.user_name).to eq(user.name)
          end

          it "sets the decidim_user on save" do
            subject.save
            expect(subject.reload.decidim_user).to eq(user)
          end

          context "when same authorization exists in another organization" do
            let(:user) { create(:user) }

            it "does not set the decidim_user on save" do
              subject.save
              expect(subject.reload.decidim_user).to be_nil
            end
          end

          context "and authorization number has different prefixes" do
            ["", "+34", "0034", "34"].each do |prefix|
              let(:user_phone) { "#{prefix}#{phone}" }

              it "has a related user" do
                expect(subject.user).to eq(user)
                expect(subject.user_from_metadata).to eq(user)
                expect(subject.user_name).to eq(user.name)
              end
            end
          end

          context "and participant number has different prefixes" do
            let(:user_phone) { "34123456" }

            ["", "+34", "0034", "34"].each do |prefix|
              let(:phone) { "#{prefix}#{user_phone}" }

              it "has a related user" do
                expect(subject.user).to eq(user)
                expect(subject.user_from_metadata).to eq(user)
                expect(subject.user_name).to eq(user.name)
              end
            end
          end
        end
      end
    end
  end
end
