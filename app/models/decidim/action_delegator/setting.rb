# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # Contains the delegation settings of an election. Rather than a single attribute here
    # a setting is the record itself: a bunch of configuration values.
    class Setting < ApplicationRecord
      self.table_name = "decidim_action_delegator_settings"

      belongs_to :organization,
                 foreign_key: "decidim_organization_id",
                 class_name: "Decidim::Organization"
      has_many :delegations,
               inverse_of: :setting,
               foreign_key: "decidim_action_delegator_setting_id",
               class_name: "Decidim::ActionDelegator::Delegation",
               dependent: :restrict_with_error
      has_many :ponderations,
               inverse_of: :setting,
               foreign_key: "decidim_action_delegator_setting_id",
               class_name: "Decidim::ActionDelegator::Ponderation",
               dependent: :restrict_with_error
      has_many :participants,
               inverse_of: :setting,
               foreign_key: "decidim_action_delegator_setting_id",
               class_name: "Decidim::ActionDelegator::Participant",
               dependent: :restrict_with_error

      validates :max_grants, presence: true
      validates :max_grants, numericality: { greater_than: 0 }

      enum :authorization_method, [:phone, :email, :both], prefix: :verify_with
      scope :active, -> { where(active: true) }
      default_scope { order(created_at: :desc) }

      def editable? = active?

      def destroyable? = participants.empty? && ponderations.empty? && delegations.empty?

      def phone_required? = verify_with_phone? || verify_with_both?

      def email_required? = verify_with_email? || verify_with_both?

      def presenter
        Decidim::ActionDelegator::SettingPresenter.new(self)
      end
    end
  end
end
