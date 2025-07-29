# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class SettingForm < Decidim::Form
        include TranslatableAttributes

        mimic :setting

        translatable_attribute :title, String
        translatable_attribute :description, String
        attribute :max_grants, Integer
        attribute :authorization_method, String
        attribute :copy_from_setting_id, Integer
        attribute :active, Boolean, default: false

        validates :max_grants, presence: true
        validates :max_grants, numericality: { greater_than: 0 }
        validates :title, translatable_presence: true
      end
    end
  end
end
