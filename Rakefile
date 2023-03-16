# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["CI"]
  require "appraisal/task"
  Appraisal::Task.new
  task default: :appraisal
else
  Rake::TestTask.new(:test) do |t|
    t.libs << "test"
    t.pattern = "test/**/*_test.rb"
    t.verbose = false
    t.warning = false
  end

  task default: :test
end