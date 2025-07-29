module Decidim
  module ActionDelegator
    module Admin
      class Permissions < Decidim::DefaultPermissions
        def permissions
          return permission_action if permission_action.scope != :admin
          return permission_action unless user && user.admin?
          return permission_action unless [:delegation, :ponderation, :participant, :setting].include?(permission_action.subject)
            
          if permission_action.action == :destroy
            toggle_allow(resource.present?)
          else
            allow!
          end
            
          permission_action
        end
      end
    end
  end
end