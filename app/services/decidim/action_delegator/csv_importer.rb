# frozen_string_literal: true

module Decidim
  module ActionDelegator
    class CsvImporter
      include Decidim::FormFactory

      def initialize(csv_file, current_user, current_setting)
        @csv_file = csv_file
        @current_user = current_user
        @current_setting = current_setting
      end

      def import!
        import_summary = {
          total_rows: 0,
          imported_rows: 0,
          error_rows: [],
          skipped_rows: [],
          details_csv_path: nil
        }

        details_csv_file = File.join(File.dirname(@csv_file), "details.csv")

        i = 1
        csv = CSV.new(@csv_file, headers: true, col_sep: ",")

        CSV.open(details_csv_file, "wb") do |details_csv|
          while (row = csv.shift).present?
            i += 1

            params = extract_params(row)

            next if row&.empty?

            handle_form_validity(row, details_csv, import_summary, i) if process(row, params, details_csv, import_summary, i)
          end
        end

        import_summary[:total_rows] = i - 1
        import_summary[:details_csv_path] = details_csv_file

        import_summary
      end

      def handle_skipped_row(row, details_csv, import_summary, row_number, reason)
        import_summary[:skipped_rows] << { row_number: row_number - 1 }
        row["reason"] = reason
        details_csv << row
      end

      def handle_import_error(row, details_csv, import_summary, row_number, error_messages)
        import_summary[:error_rows] << { row_number: row_number - 1, error_messages: }
        row["reason"] = error_messages
        details_csv << row
      end

      def handle_form_validity(row, details_csv, import_summary, row_number)
        raise NotImplementedError
      end

      def generate_info_message(mismatch_fields)
        with_mismatched_fields = mismatch_fields.present? ? I18n.t("decidim.action_delegator.participants_csv_importer.import.with_mismatched_fields", fields: mismatch_fields) : ""
        I18n.t("decidim.action_delegator.participants_csv_importer.import.skip_import_info", with_mismatched_fields:)
      end

      def headers(csv, details_csv)
        headers = csv.first.headers
        headers << I18n.t("decidim.action_delegator.participants_csv_importer.import.error_field")
        details_csv << headers
      end

      def invalid_email?(email)
        email.blank? || !email.match?(::Devise.email_regexp)
      end

      def process(row)
        raise NotImplementedError
      end

      def extract_params
        raise NotImplementedError
      end
    end
  end
end
