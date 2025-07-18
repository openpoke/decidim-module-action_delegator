# app/forms/decidim/action_delegator/admin/delegation_import_form.rb
module Decidim
  module ActionDelegator
    module Admin
      class CsvImportForm < Decidim::Form
        include Decidim::HasUploadValidations

        attribute :csv_file, Decidim::Attributes::Blob
        attribute :setting_id, Integer

        validates :csv_file, presence: true, file_content_type: { allow: ["text/csv"] }
      end
    end
  end
end
