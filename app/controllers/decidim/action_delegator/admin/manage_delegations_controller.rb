# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class ManageDelegationsController < ActionDelegator::Admin::ApplicationController
        include NeedsPermission
        include Decidim::Paginable

        helper ::Decidim::ActionDelegator::Admin::DelegationHelper
        helper_method :organization_settings, :current_setting

        layout "decidim/admin/users"

        def new
          enforce_permission_to :create, :delegation

          @form = CsvImportForm.from_params(params)
          @errors = []
        end

        def create
          enforce_permission_to :create, :delegation

          @form = CsvImportForm.from_params(params)

          if @form.valid?
            csv_file = @form.csv_file.download.force_encoding("utf-8").encode("utf-8")
            @import_summary = ImportCsvJob.perform_now("DelegationsCsvImporter", csv_file, current_user, current_setting)
            flash[:notice] = t(".success")
            redirect_to setting_delegations_path(current_setting)
          else
            render :new
          end
        end
      end
    end
  end
end
