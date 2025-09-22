# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class SettingPresenter < SimpleDelegator
      include Decidim::TranslationsHelper

      def initialize(setting)
        @setting = setting

        super
      end

      def translated_title
        translated_attribute(__getobj__.title).html_safe
      end

      def translated_description
        ActionView::Base.full_sanitizer.sanitize(translated_attribute(__getobj__.description)).html_safe
      end

      def translated_resources_list
        Decidim::ActionDelegator::AuthorizedResources.new(setting: self).query.map(&:presenter)
      end

      def path_for(resource)
        return nil unless resource

        Decidim::ResourceLocatorPresenter.new(resource).path
      end
    end
  end
end
