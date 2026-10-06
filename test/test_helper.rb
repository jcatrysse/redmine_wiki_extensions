require "rails"
require "simplecov"
require "shoulda"
require "simplecov-lcov"

# shoulda-context 2.0 replaces Rails::TestUnitReporter#format_rerun_snippet with
# a version that calls an instance method `executable`, which Rails 7.1+ only
# defines on the class. Without this the run aborts on the first failure.
require "rails/test_unit/reporter"
unless Rails::TestUnitReporter.method_defined?(:executable)
  Rails::TestUnitReporter.class_eval do
    def executable
      self.class.executable
    end
  end
end


SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = File.expand_path(File.dirname(__FILE__) + "/../coverage/lcov.info")
end

SimpleCov.formatters = [
  SimpleCov::Formatter::LcovFormatter,
  SimpleCov::Formatter::HTMLFormatter
]

SimpleCov.start do
  root File.expand_path(File.dirname(__FILE__) + "/..")
  add_filter "/test/"
end

# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + "/../../../test/test_helper")

fixtures = []
Dir.chdir(File.dirname(__FILE__) + "/fixtures/") do
  fixtures = Dir.glob("*.yml").map { |s| s.gsub(/.yml$/, "") }
end
ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + "/fixtures/", fixtures)

# Ensure that we are using the temporary fixture path
# Engines::Testing.set_fixture_path
