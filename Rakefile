# frozen_string_literal: true

require "decidim/generators/app_generator"

def generate_decidim_app(*options)
  app_path = File.expand_path(options.first, Dir.pwd)

  sh "rm -fR #{app_path}", verbose: false

  original_folder = Dir.pwd

  Decidim::Generators::AppGenerator.start(options)

  Dir.chdir(original_folder)
end

def base_app_name
  File.basename(Dir.pwd).underscore
end

def install_module(path)
  Dir.chdir(path) do
    system("bundle exec rake decidim_elections:install:migrations")
    system("bundle exec rake decidim_action_delegator:install:migrations")
    system("bundle exec rake db:migrate")
  end
end

def seed_db(path)
  Dir.chdir(path) do
    system("bundle exec rake db:seed")
  end
end

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app" do
  ENV["RAILS_ENV"] = "test"
  install_module("spec/decidim_dummy_app")
end

desc "Generates a development app."
task :development_app do
  Bundler.with_original_env do
    generate_decidim_app(
      "development_app",
      "--app_name",
      "#{base_app_name}_development_app",
      "--path",
      "..",
      "--recreate_db",
      "--demo",
      "--locales", "en,ca,es",
      "--queue=sidekiq"
    )
  end

  install_module("development_app")
  seed_db("development_app")
end
