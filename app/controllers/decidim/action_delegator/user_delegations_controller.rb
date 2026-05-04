# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # This controller handles user profile actions for this module
    class UserDelegationsController < ActionDelegator::ApplicationController
      include Decidim::UserProfile

      helper_method :delegations, :active_pairs

      def index
        enforce_permission_to :read, :user, current_user: current_user
      end

      private

      def delegations
        @delegations ||= user_signed_in? ? Delegation.where(grantee_id: current_user.id).includes(:setting) : Delegation.none
      end

      def active_pairs
        @active_pairs ||= delegations.flat_map { |d| d.setting.elections.published.ongoing.map { |e| [e, d] } }
      end
    end
  end
end
