# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      # This controller is the abstract class from which all other controllers of
      # this engine inherit.
      class ApplicationController < Decidim::Admin::ApplicationController
        helper_method :organization_settings, :current_setting

        def permission_class_chain
          [::Decidim::ActionDelegator::Admin::Permissions] + super
        end

        def organization_settings
          @organization_settings ||= ActionDelegator::Setting.where(organization: current_organization)
        end

        def current_setting
          @current_setting ||= organization_settings.find_by(id: params[:setting_id])
        end
      end
    end
  end
end
