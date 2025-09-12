# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/action_delegator/version"

Gem::Specification.new do |s|
  s.version = Decidim::ActionDelegator::VERSION
  s.authors = ["Pau Pérez Fabregat", "Ivan Vergés"]
  s.email = %w(saulopefa@gmail.com ivan@pokecode.net)
  s.license = "AGPL-3.0"
  s.homepage = "https://github.com/Openpoke/decidim-module-action_delegator"
  s.required_ruby_version = "~> 3.3.0"

  s.name = "decidim-action_delegator"
  s.summary = "A Decidim ActionDelegator module"
  s.description = "A tool for Decidim that provides extended functionalities for cooperatives and allows delegated voting."

  s.files = Dir["{app,config,lib,db}/**/*", "LICENSE-AGPLv3.txt", "Rakefile", "package.json", "package-json.lock", "README.md"]

  s.add_dependency "decidim-admin", Decidim::ActionDelegator::COMPAT_DECIDIM_VERSION
  s.add_dependency "decidim-core", Decidim::ActionDelegator::COMPAT_DECIDIM_VERSION
  s.add_dependency "decidim-elections", Decidim::ActionDelegator::COMPAT_DECIDIM_VERSION
  s.add_dependency "deface", ">= 1.9"
  s.add_dependency "savon"
  s.add_dependency "twilio-ruby"

  s.metadata["rubygems_mfa_required"] = "true"
end
