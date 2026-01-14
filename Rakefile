# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc "Run RSpec code examples in specdoc mode"
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = %w[--backtrace --colour --format doc]
  end
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

RuboCop::RakeTask.new

task default: %i[spec rubocop]
