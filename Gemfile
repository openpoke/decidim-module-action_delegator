# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

# Inside the development app, the relative require has to be one level up, as
# the Gemfile is copied to the development_app folder (almost) as is.
base_path = ""
base_path = "../" if File.basename(__dir__) == "development_app"
require_relative "#{base_path}lib/decidim/action_delegator/version"

DECIDIM_VERSION = Decidim::ActionDelegator::DECIDIM_VERSION

gem "puma", ">= 6.3.1"

gem "decidim", DECIDIM_VERSION
gem "decidim-action_delegator", path: "."
gem "decidim-elections", DECIDIM_VERSION
gem "decidim-initiatives", DECIDIM_VERSION

gem "bootsnap", "~> 1.4"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "decidim-dev", DECIDIM_VERSION
  gem "brakeman", "~> 7.0"
  gem "parallel_tests", "~> 4.2"
end

group :development do
  gem "letter_opener_web"
  gem "web-console"
end

group :test do
  gem "shoulda-matchers"
end
