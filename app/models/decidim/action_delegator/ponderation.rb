# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class Ponderation < ApplicationRecord
      self.table_name = "decidim_action_delegator_ponderations"

      belongs_to :setting,
                 foreign_key: "decidim_action_delegator_setting_id",
                 class_name: "Decidim::ActionDelegator::Setting"

      has_many :participants,
               foreign_key: "decidim_action_delegator_ponderation_id",
               class_name: "Decidim::ActionDelegator::Participant",
               dependent: :restrict_with_error

      def title
        @title ||= "#{name} (x#{weight})"
      end

      def destroyable?
        participants.empty?
      end
    end
  end
end
