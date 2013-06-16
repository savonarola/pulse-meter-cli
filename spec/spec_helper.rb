require 'rubygems'
require 'bundler/setup'
$:.unshift File.expand_path('../../lib/', __FILE__)

ROOT = File.expand_path('../..', __FILE__)

Bundler.require(:development)

SimpleCov.start

require 'pulse_meter_cli'
PulseMeter.redis = MockRedis.new

RSpec.configure do |config|
  config.before(:each) do
    PulseMeter.redis = MockRedis.new
    Timecop.return
    PulseMeter.logger = Logger.new("/dev/null")
  end
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end

