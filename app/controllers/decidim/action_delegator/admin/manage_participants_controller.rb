# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      class ManageParticipantsController < ActionDelegator::Admin::ApplicationController
        include NeedsPermission
        include Decidim::Paginable

        helper ::Decidim::ActionDelegator::Admin::DelegationHelper
        helper_method :organization_settings, :current_setting

        layout "decidim/admin/users"

        def new
          enforce_permission_to :create, :participant

          @form = CsvImportForm.from_params(params)
          @errors = []
        end

        def create
          enforce_permission_to :create, :participant

          @form = CsvImportForm.from_params(params)

          if @form.valid?
            csv = @form.csv_file.download.force_encoding("utf-8").encode("utf-8")
            @import_summary = ImportCsvJob.perform_now("ParticipantsCsvImporter", csv, current_user, current_setting)
            flash[:notice] = t(".success")
            redirect_to setting_participants_path(current_setting)
          else
            render :new
          end
        end

        def destroy_all
          enforce_permission_to :destroy, :participant, { resource: current_setting }

          participants_to_remove = current_setting.participants.reject(&:voted?)

          participants_to_remove.each(&:destroy)

          flash[:notice] = I18n.t("participants.remove_census.success", scope: "decidim.action_delegator.admin", participants_count: participants_to_remove.count)
          redirect_to setting_participants_path(current_setting)
        end
      end
    end
  end
end
