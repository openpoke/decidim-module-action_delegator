# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class SettingPresenter < SimpleDelegator
      def translated_title
        translated_attribute(title).html_safe
      end

      def translated_description
        ActionView::Base.full_sanitizer.sanitize(translated_attribute(description)).html_safe
      end

      def translated_resources_list
        Decidim::ActionDelegator::AuthorizedResources.new(setting: self).query.map(&:presenter)
      end
    end
  end
end
