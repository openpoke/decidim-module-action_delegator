# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class SettingForm < Form
        mimic :setting

        attribute :max_grants, Integer
        attribute :decidim_election_id, Integer
        attribute :authorization_method, String
        attribute :copy_from_setting_id, Integer

        validates :max_grants, :decidim_election_id, presence: true
        validate :election_uniqueness

        # TODO: validate election vote starting in the future
        def election_uniqueness
          errors.add(:decidim_election_id, :taken) if record.exists?(decidim_election_id:)
        end

        def record
          Setting.where.not(id: id)
        end
      end
    end
  end
end
