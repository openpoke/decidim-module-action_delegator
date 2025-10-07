# frozen_string_literal: true

module Decidim
  module ActionDelegator
    # Returns all PaperTrail versions of a election's delegated votes for auditing purposes.
    # It is intended to be used to easily fetch this data when a judge ask us so.
    class ElectionsDelegatedVotesVersions
      def initialize(election)
        @election = election
        @settings = ElectionSettings.new(election).query
      end

      def query
        PaperTrail::Version
          .joins("INNER JOIN decidim_action_delegator_delegations ON decidim_action_delegator_delegations.id = versions.decidim_action_delegator_delegation_id")
          .joins("INNER JOIN decidim_action_delegator_settings ON decidim_action_delegator_settings.id = decidim_action_delegator_delegations.decidim_action_delegator_setting_id")
          .where(item_type: "Decidim::Elections::Vote")
          .where(decidim_action_delegator_settings: { id: @settings.select(:id) })
          .order("versions.created_at ASC")
      end

      attr_reader :election, :settings
    end
  end
end
