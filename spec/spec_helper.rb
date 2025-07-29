# frozen_string_literal: true

require "decidim/dev"

require "simplecov"

SimpleCov.start "rails"
if ENV["CODECOV"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

ENV["ENGINE_ROOT"] = File.dirname(__dir__)

Decidim::Dev.dummy_app_path =
  File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require "decidim/dev/test/base_spec_helper"

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

require_relative "support/custom_autocomplete_select"

RSpec.configure do |config|
  config.include CustomAutoCompleteSelect, type: :system
end
