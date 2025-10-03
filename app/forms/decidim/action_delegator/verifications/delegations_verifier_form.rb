# frozen_string_literal: true

require "securerandom"

module Decidim
  module ActionDelegator
    module Verifications
      # This verifier checks if there is some setting in which the participant is required
      # to verify it's phone (the first active setting will be used for that).
      # If no setting requires phone verification, it will check if there is some setting
      # in which the participant is required to verify it's email.
      # If no setting requires email verification, the user won't be able to proceed.
      # If there are multiple active settings, the user will be verified for the first one
      #
      # Note that the ActionAuthorizer associated with this handler will check the current status
      # of the settings and delegations regardless of this verification metadata
      class DelegationsVerifierForm < AuthorizationHandler
        attribute :email, String
        attribute :phone, String

        validates :verification_code, :sms_gateway, presence: true, if: ->(form) { form.setting&.phone_required? }
        validates :phone, presence: true, if: ->(form) { form.setting&.phone_required? }
        validates :email, presence: true, if: ->(form) { form.setting&.email_required? }

        validate :user_in_census

        alias user current_user

        def handler_name
          "delegations_verifier"
        end

        def unique_id
          Digest::MD5.hexdigest(
            "#{setting&.phone_required? ? phone : email}-#{setting&.organization&.id}-#{Digest::MD5.hexdigest(Rails.application.secret_key_base)}"
          )
        end

        # email is predefined always
        delegate :email, to: :current_user

        # When there's a phone number, sanitize it allowing only numbers and +.
        def phone
          return find_phone if setting&.verify_with_both?
          return unless super

          super.gsub(/[^+0-9]/, "")
        end

        def metadata
          {
            phone:,
            setting_ids:
          }
        end

        def setting_ids
          return [] unless current_user

          valid_participants&.map(&:decidim_action_delegator_setting_id)&.uniq || []
        end

        # The verification metadata to validate in the next step.
        def verification_metadata
          {
            verification_code: verification_code,
            code_sent_at: Time.current
          }
        end

        # currently, we rely on the last setting.
        # This could be improved by allowing the user to select the setting (or related phone).
        def active_settings
          @active_settings ||= context[:active_settings]
        end

        # find the participant in any of the active settings
        # If phone is required, just find the first participant and validate the phone
        # if not, find by email in any of the active settings
        def participant
          valid_participants&.first
        end

        def valid_participants
          return [] unless setting

          @valid_participants ||= begin
            params = {}
            params[:email] = email if setting.email_required?
            if setting.phone_required?
              if phone.blank?
                @valid_participants = setting.participants.none
              else
                params[:phone] = phone_prefixes.map { |prefix| "#{prefix}#{phone}" }
                params[:phone] += phone_prefixes.map { |prefix| phone.delete_prefix(prefix).to_s }
              end
            end

            setting.participants.where(params)
          end
        end

        # find the first setting where phone is required or, if not, the first setting where email is required
        # This works because the email is unique per user so it does not matter which setting we use to find the participant
        # If the setting requires phone, only one active setting with phone verification is allowed to exist at a time
        def setting
          @setting ||= active_settings&.phone_required&.first || active_settings&.email_required&.first
        end

        private

        def phone_prefixes
          return [] unless ActionDelegator.phone_prefixes.respond_to?(:map)

          ActionDelegator.phone_prefixes
        end

        def user_in_census
          return if errors.any?
          return if participant

          errors.add(:phone, :phone_not_found) if setting&.phone_required?
          errors.add(:email, :email_not_found) if setting&.email_required?
        end

        def verification_code
          return unless sms_gateway
          return @verification_code if defined?(@verification_code)

          return unless sms_gateway.new(phone, generated_code).deliver_code

          @verification_code = generated_code
        end

        def sms_gateway
          (Decidim.sms_gateway_service || ActionDelegator.sms_gateway_service).to_s.safe_constantize
        end

        def generated_code
          @generated_code ||= SecureRandom.random_number(1_000_000).to_s
        end

        def find_phone
          @find_phone ||= setting.participants.find_by(email: email)&.phone
        end
      end
    end
  end
end
