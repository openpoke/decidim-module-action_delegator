# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class ParticipantsCsvImporter < CsvImporter
      def process(row, params, details_csv, import_summary, iterator)
        weight = ponderation_value(row["weight"].strip) if row["weight"].present?

        @form = form(Decidim::ActionDelegator::Admin::ParticipantForm).from_params(params, setting: @current_setting)

        if participant_exists?(@form)
          mismatch_fields = mismatched_fields(@form)
          message = generate_info_message(mismatch_fields)
          handle_skipped_row(row, details_csv, import_summary, iterator, message)
          return false
        end
        if phone_exists?(@form)
          reason = I18n.t("phone_exists", scope: "decidim.action_delegator.participants_csv_importer.import")
          handle_skipped_row(row, details_csv, import_summary, iterator, reason)
          return false
        end
        if weight.present? && find_ponderation(weight).nil?
          reason = I18n.t("ponderation_not_found", scope: "decidim.action_delegator.participants_csv_importer.import")
          handle_skipped_row(row, details_csv, import_summary, iterator, reason)
          return false
        end

        true
      end

      private

      def authorization_method
        @current_setting.authorization_method
      end

      def extract_params(row)
        email, phone, weight = extract_contact_details(row, authorization_method)
        weight = ponderation_value(row["weight"].strip) if row["weight"].present?

        params = {
          email: email,
          phone: phone,
          weight: weight,
          decidim_action_delegator_ponderation_id: find_ponderation(weight)&.id
        }

        @form = form(Decidim::ActionDelegator::Admin::ParticipantForm).from_params(params, setting: @current_setting)

        params
      end

      def extract_contact_details(row, authorization_method)
        email = row["email"].to_s.strip.downcase
        phone = row["phone"].to_s.strip

        email = nil if %w(email both).include?(authorization_method.to_s) && invalid_email?(email)

        phone = nil if %w(phone both).include?(authorization_method.to_s) && invalid_phone?(phone)

        [email, phone]
      end

      def invalid_phone?(phone)
        phone.blank? || !phone.gsub(/[^+0-9]/, "").match?(Decidim::ActionDelegator.phone_regex)
      end

      def process_participant(form)
        if find_ponderation(form.weight).present?
          ponderation = find_ponderation(form.weight)
          form.decidim_action_delegator_ponderation_id = ponderation.id
        end

        create_new_participant(form)
      end

      def participant_exists?(form)
        check_exists?(:email, form)
      end

      def phone_exists?(form)
        check_exists?(:phone, form)
      end

      def check_exists?(field, form)
        @participant = Decidim::ActionDelegator::Participant.find_by(field => form.send(field), :setting => @current_setting) if form.send(field).present?
        @participant.present?
      end

      def handle_form_validity(row, details_csv, import_summary, row_number)
        if @form.valid?
          process_participant(@form)
          import_summary[:imported_rows] += 1
        else
          handle_import_error(row, details_csv, import_summary, row_number, @form.errors.full_messages.join(", "))
        end
      end

      def mismatched_fields(form)
        mismatch_fields = []
        mismatch_fields << I18n.t("decidim.action_delegator.participants_csv_importer.import.field_name.phone") if form.phone != @participant.phone

        if form.decidim_action_delegator_ponderation_id != @participant.decidim_action_delegator_ponderation_id
          mismatch_fields << I18n.t("decidim.action_delegator.participants_csv_importer.import.field_name.weight")
        end

        mismatch_fields.empty? ? nil : mismatch_fields.join(", ")
      end

      def create_new_participant(form)
        Decidim::ActionDelegator::Admin::CreateParticipant.call(form)
      end

      def find_ponderation(weight)
        case weight
        when String
          @current_setting.ponderations.find_by(name: weight).presence
        when Numeric
          ponderation = @current_setting.ponderations.find_by(weight: weight)
          ponderation.presence || @current_setting.ponderations.create(name: "weight-#{weight}", weight: weight)
        end
      end

      def ponderation_value(value)
        Float(value)
      rescue StandardError
        value
      end
    end
  end
end
