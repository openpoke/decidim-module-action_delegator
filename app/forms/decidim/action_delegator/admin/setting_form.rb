# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class SettingForm < Decidim::Form
        include TranslatableAttributes

        mimic :setting

        attribute :max_grants, Integer
        attribute :authorization_method, String
        attribute :copy_from_setting_id, Integer
        translatable_attribute :title, String
        translatable_attribute :description, String

        validates :max_grants, presence: true
        validates :max_grants, numericality: { greater_than: 0 }
        validates :title, translatable_presence: true

        def record
          Setting.where.not(id: id)
        end
      end
    end
  end
end
