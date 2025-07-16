# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class SettingForm < Form
        mimic :setting

        attribute :max_grants, Integer
        attribute :authorization_method, String
        attribute :copy_from_setting_id, Integer

        validates :max_grants, presence: true

        def record
          Setting.where.not(id: id)
        end
      end
    end
  end
end
