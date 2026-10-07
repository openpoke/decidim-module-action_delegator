# frozen_string_literal: true

module Decidim
  # This holds the decidim-action_delegator version.
  module ActionDelegator
    VERSION = "0.10.0"
    DECIDIM_VERSION = { github: "openpoke/decidim", branch: "0.32-backports" }.freeze
    COMPAT_DECIDIM_VERSION = [">= 0.32", "< 0.33"].freeze
  end
end
