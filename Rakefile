# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Create and push tag'
task :local_release do
  require_relative 'lib/em_easy_scraper/version'
  system("git tag v#{EmEasyScraper::VERSION}")
  system('git push --tags')
end
