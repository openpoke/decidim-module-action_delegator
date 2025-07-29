# frozen_string_literal: true

module Decidim
  # This holds the decidim-action_delegator version.
  module ActionDelegator
    VERSION = "0.9.0"
    DECIDIM_VERSION = { github: "decidim/decidim", branch: "feature/add-election-voting-booth" }.freeze
    COMPAT_DECIDIM_VERSION = [">= 0.31.0.dev", "< 0.32"].freeze
  end
end
