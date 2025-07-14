# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      module Consultations
        class ExportsController < ActionDelegator::Admin::ApplicationController
          include NeedsPermission

          def create
            enforce_permission_to :export_consultation_results, :consultation, consultation: current_consultation

            ExportConsultationResultsJob.perform_later(current_user, current_consultation, type)

            flash[:notice] = t("decidim.admin.exports.notice")
            redirect_back(fallback_location: decidim_admin_consultations.results_consultation_path(current_consultation))
          end

          def type
            "type_and_weight"
          end
        end
      end
    end
  end
end
