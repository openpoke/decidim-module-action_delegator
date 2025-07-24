# frozen_string_literal: true

require "securerandom"

module Decidim
  module ActionDelegator
    module Verifications
      # A form object to be used when public users want to get verified using their phone.
      class DelegationsVerifierForm < AuthorizationHandler
        attribute :email, String
        attribute :phone, String

        validates :verification_code, :sms_gateway, presence: true
        validates :phone, presence: true, if: ->(form) { form.setting&.phone_required? }
        validates :email, presence: true, if: ->(form) { form.setting&.email_required? }
        validate :setting_exists
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
            phone: phone
          }
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
        def setting
          @setting ||= context[:setting]
        end

        def participants
          @participants ||= Decidim::ActionDelegator::Participant.where(setting: setting)
        end

        def participant
          return unless setting

          @participant ||= begin
            params = {}
            params[:email] = email if setting.email_required?
            if setting.phone_required?
              if phone.blank?
                @participant = setting.participants.none
              else
                params[:phone] = phone
                params[:phone] = phone_prefixes.map { |prefix| "#{prefix}#{phone}" }
                params[:phone] += phone_prefixes.map { |prefix| phone.delete_prefix(prefix).to_s }
              end
            end

            setting.participants.find_by(params)
          end
        end

        private

        def phone_prefixes
          return [] unless ActionDelegator.phone_prefixes.respond_to?(:map)

          ActionDelegator.phone_prefixes
        end

        def user_in_census
          return if errors.any?
          return if participant

          errors.add(:phone, :phone_not_found) if setting.phone_required?
          errors.add(:email, :email_not_found) if setting.email_required?
        end

        def setting_exists
          return if errors.any?
          return if setting

          errors.add(:phone, :invalid)
          errors.add(:email, :invalid)
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
