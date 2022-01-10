require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"
require "appraisal"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
  t.warning = false
end

task default: :test
