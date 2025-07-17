# frozen_string_literal: true

module Decidim
  module ActionDelegator
    module Admin
      module DelegationHelper
        def granters_for_select
          current_organization.users
        end

        def grantees_for_select
          current_organization.users
        end

        def resources_for_select
          organization_elections.map { |election| [translated_attribute(election.title), election.id] }
        end

        def ponderations_for_select(setting)
          setting.ponderations.map { |ponderation| [ponderation.title, ponderation.id] }
        end

        def organization_elections
          Decidim::ActionDelegator::OrganizationElections.new(current_organization).query
        end

        def missing_verifications_for(resources, action)
          resources.where.not(id: Decidim::ResourcePermission.select(:resource_id)
            .where(resource: resources)
            .where(Arel.sql("permissions->'#{action}'->'authorization_handlers'->>'delegations_verifier' IS NOT NULL")))
        end

        def missing_decidim_users(participants)
          participants.where(decidim_user: nil).or(participants.where.not(decidim_user: current_organization.users)).where.not(id: missing_registered_users(participants))
        end

        # TODO: need to check
        def missing_registered_users(participants)
          participants.where.not(email: current_organization.users.select(:email))
                      .where.not("MD5(CONCAT(phone, '-', CAST(? AS text), '-', CAST(? AS text))) IN (?)",
                                 current_organization.id,
                                 Digest::MD5.hexdigest(Rails.application.secret_key_base),
                                 Authorization.select(:unique_id).where.not(unique_id: nil))
        end

        def participants_uniq_ids(participants)
          phones = Participant.phone_combinations(participants.pluck(:phone))
          Participant.verifier_ids(Participant.phone_combinations(phones.map { |phone| "#{phone}-#{current_organization.id}" }))
        end

        def existing_authorizations(participants)
          uniq_ids = participants_uniq_ids(participants)
          user_ids = current_organization.users.select(:id).where(email: participants.select(:email))
          Decidim::Authorization.select(:decidim_user_id).where(unique_id: uniq_ids).or(
            Decidim::Authorization.select(:decidim_user_id).where(decidim_user_id: user_ids)
          )
        end

        def total_missing_authorizations(participants)
          participants.count - existing_authorizations(participants).count
        end
      end
    end
  end
end
