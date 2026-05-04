# frozen_string_literal: true

module Decidim
  # This holds the decidim-action_delegator version.
  module ActionDelegator
    VERSION = "0.9.3"
    DECIDIM_VERSION = { github: "openpoke/decidim", branch: "0.31-backports" }.freeze
    COMPAT_DECIDIM_VERSION = [">= 0.31", "< 0.32"].freeze
  end
end
