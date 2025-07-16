# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      # This controller is the abstract class from which all other controllers of
      # this engine inherit.
      class ApplicationController < Decidim::Admin::ApplicationController
        register_permissions(ApplicationController,
                             ActionDelegator::Permissions,
                             Decidim::Admin::Permissions)
        def permission_class_chain
          Decidim.permissions_registry.chain_for(ApplicationController)
        end
      end
    end
  end
end
