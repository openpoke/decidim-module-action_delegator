# frozen_string_literal: true

require "decidim/action_delegator/verifications/delegations_authorizer"
require "decidim/action_delegator/verifications/delegations_verifier"
require "decidim/action_delegator/admin"
require "decidim/action_delegator/admin_engine"
require "decidim/action_delegator/engine"

module Decidim
  # This namespace holds the logic of the `ActionDelegator` module
  module ActionDelegator
    include ActiveSupport::Configurable

    # this is the SmsGateway provided by this module
    # Note that it will be ignored if you provide your own SmsGateway in Decidim.sms_gateway_service
    config_accessor :sms_gateway_service do
      Decidim::Env.new("AD_SMS_GATEWAY_SERVICE", "Decidim::ActionDelegator::SmsGateway").to_s
    end

    # The default expiration time for the integrated authorization
    # if zero, the authorization won't be registered
    config_accessor :authorization_expiration_time do
      Decidim::Env.new("AD_AUTHORIZATION_EXPIRATION_TIME").presence&.to_i || 3.months
    end

    # Put this to false if you don't want to allow administrators to invite users not registered
    # in the platform when uploading a census (inviting users without permission can be a GDPR offense).
    config_accessor :allow_to_invite_users do
      Decidim::Env.new("AD_ALLOW_TO_INVITE_USERS", true).present?
    end

    # If true, tries to automatically authorize users when they log in with the "Corporate Governance Verifier"
    # Note that this is only possible when the verifier is configured to use only the email (if SMS is required, the user will have to do the standard verification process)
    config_accessor :authorize_on_login do
      Decidim::Env.new("AD_AUTHORIZE_ON_LOGIN", true).present?
    end

    # used for comparing phone numbers from a census list and the ones introduced by the user
    # the phone number will be normalized before comparing it so, for instance,
    # if you have a census list with  +34 666 666 666 and the user introduces 0034666666666 or 666666666, they will be considered the same
    # can be empty or null if yo don't want to check different combinations of prefixes
    config_accessor :phone_prefixes do
      Decidim::Env.new("AD_PHONE_PREFIXES", "+34,0034,34").to_array
    end

    # The regex for validating phone numbers
    config_accessor :phone_regex do
      Decidim::Env.new("AD_PHONE_REGEX", '^\d{6,15}$').to_s # 6 to 15 digits
    end
  end
end

# We register 2 global engines to handle logic unrelated to participatory spaces or components

# User space engine, used mostly in the context of the user profile to let the users
# manage their delegations
Decidim.register_global_engine(
  :decidim_action_delegator, # this is the name of the global method to access engine routes
  Decidim::ActionDelegator::Engine,
  at: "/action_delegator"
)

# Admin side of the delegations management. Admins can overlook all delegations and
# create their own
Decidim.register_global_engine(
  :decidim_admin_action_delegator,
  Decidim::ActionDelegator::AdminEngine,
  at: "/admin/action_delegator"
)
