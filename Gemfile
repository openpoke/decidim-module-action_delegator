# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

# Inside the development app, the relative require has to be one level up, as
# the Gemfile is copied to the development_app folder (almost) as is.
base_path = ""
base_path = "../" if File.basename(__dir__) == "development_app"
require_relative "#{base_path}lib/decidim/action_delegator/version"

# DECIDIM_VERSION = Decidim::ActionDelegator::DECIDIM_VERSION
DECIDIM_VERSION = { github: "decidim/decidim", branch: "develop" }

gem "decidim", DECIDIM_VERSION
gem "decidim-action_delegator", path: "."
gem "decidim-elections", DECIDIM_VERSION
gem "decidim-initiatives", DECIDIM_VERSION

gem "bootsnap", "~> 1.4"
gem "savon", "~> 2.12"
gem "twilio-ruby", "~> 5.41"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "decidim-dev", DECIDIM_VERSION
end

group :development do
  gem "faker", "~> 3.2"
  gem "letter_opener_web", "~> 2.0"
  gem "listen", "~> 3.1"
  gem "rubocop-faker"
  gem "web-console"
end

group :test do
  gem "codecov", require: false
  gem "shoulda-matchers"
end
