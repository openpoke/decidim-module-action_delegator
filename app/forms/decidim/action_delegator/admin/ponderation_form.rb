# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class PonderationForm < Form
        mimic :ponderation

        attribute :weight, Decimal, default: 1.0
        attribute :name, String

        validates :name, presence: true
        validates :weight, presence: true, numericality: { greater_than: 0 }
        validate :name_uniqueness

        def name_uniqueness
          return unless setting
          return unless setting.ponderations.where(name: name).where.not(id: id).any?

          errors.add(:name, :taken)
        end

        def setting
          @setting ||= context[:setting]
        end
      end
    end
  end
end
