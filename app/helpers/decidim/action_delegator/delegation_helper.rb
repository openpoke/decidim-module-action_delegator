# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module DelegationHelper
      def settings_for(resource)
        case resource
        when Decidim::Elections::Election
          Decidim::ActionDelegator::ElectionSettings.new(resource).query
        else
          Decidim::ActionDelegator::Setting.none
        end
      end

      def delegations_for(resource, user)
        case resource
        when Decidim::Elections::Election
          Decidim::ActionDelegator::Delegation.where(
            setting: settings_for(resource),
            grantee: user
          )
        else
          Decidim::ActionDelegator::Delegation.none
        end
      end

      def participant_voted?(resource, user)
        case resource
        when Decidim::Elections::Election
          resource.votes.exists?(voter_uid: user.to_global_id.to_s)
        else
          false
        end
      end
    end
  end
end
