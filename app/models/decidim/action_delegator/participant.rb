# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class Participant < ApplicationRecord
      self.table_name = "decidim_action_delegator_participants"

      belongs_to :setting,
                 foreign_key: "decidim_action_delegator_setting_id",
                 class_name: "Decidim::ActionDelegator::Setting"

      belongs_to :ponderation,
                 foreign_key: "decidim_action_delegator_ponderation_id",
                 class_name: "Decidim::ActionDelegator::Ponderation",
                 optional: true

      belongs_to :decidim_user,
                 class_name: "Decidim::User",
                 optional: true

      delegate :organization, to: :setting

      validates :decidim_user, uniqueness: { scope: :setting }, if: -> { decidim_user.present? }
      validates :email, uniqueness: { scope: :setting }, if: -> { email.present? }
      validates :phone, uniqueness: { scope: :setting }, if: -> { phone.present? }

      validate :user_belongs_to_organization

      # sets the decidim user if found
      before_save :set_decidim_user

      # prevents destroy if has voted
      before_destroy { |record| throw(:abort) if record.voted? }

      def user
        @user ||= decidim_user || user_from_metadata
      end

      def user_from_metadata
        @user_from_metadata ||= if setting&.email_required?
                                  Decidim::User.find_by(email: email, organization: setting.organization)
                                else
                                  Decidim::Authorization.find_by(unique_id: uniq_ids)&.user
                                end
      end

      def uniq_ids
        @uniq_ids ||= Participant.verifier_ids(Participant.phone_combinations(["#{phone}-#{organization.id}"]))
      end

      def self.verifier_ids(seeds)
        seeds.map { |seed| Digest::MD5.hexdigest("#{seed}-#{Digest::MD5.hexdigest(Rails.application.secret_key_base)}") }
      end

      def self.phone_combinations(phones)
        phones.map do |phone|
          phone_prefixes.map do |prefix|
            [
              "#{prefix}#{phone}",
              phone.delete_prefix(prefix)
            ]
          end
        end.flatten.uniq
      end

      def self.phone_prefixes
        prefixes = [""]
        prefixes += ActionDelegator.phone_prefixes if ActionDelegator.phone_prefixes.respond_to?(:map)
        prefixes
      end

      def user_name
        user&.name
      end

      def last_login
        user&.last_sign_in_at
      end

      def ponderation_title
        ponderation&.title
      end

      # checks if the user has voted
      def voted?
        return false if user.blank?

        # TODO: Replace vote check once new context is defined
        false
      end

      private

      def set_decidim_user
        self.decidim_user = user_from_metadata if decidim_user.blank?
      end

      def user_belongs_to_organization
        # TODO: Enable validation when context is restored
        true
      end
    end
  end
end
