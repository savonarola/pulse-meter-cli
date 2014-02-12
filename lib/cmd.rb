require 'thor'
require 'terminal-table'
require 'time'
require 'json'
require 'csv'

module Cmd
  class All < Thor
    include PulseMeter::Mixins::Utils
    include PulseMeter::Mixins::Cmd
    no_tasks do
      def create_redis
        Redis.new :host => options[:host], :port => options[:port], :db => options[:db]
      end

      def self.common_options
        method_option :host, :default => '127.0.0.1', :desc => "Redis host"
        method_option :port, :default => 6379, :desc => "Redis port"
        method_option :db, :default => 0, :desc => "Redis db"
      end

      def self.sensor_options(required = [])
        [
          [:interval, :numeric, "Rotation interval"],
          [:ttl, :numeric, "How long summarized data will be stored"],
          [:raw_data_ttl, :numeric, "How long unsummarized raw data will be stored"],
          [:reduce_delay, :numeric, "Delay between end of interval and summarization"],
          [:annotation, :string, "Sensor annotation"]
        ].each do |name, type, desc = data|
          method_option name, :required => required.include?(name), :type => type, :desc => desc
        end
      end
    end

    desc "sensors", "List all sensors available"
    common_options
    method_option :format, :default => :table, :desc => "Output format: table or csv"
    def sensors
      with_redis {puts all_sensors_table(options[:format])}
    end

    desc "reduce", "Execute reduction for all sensors' raw data"
    common_options
    def reduce
      with_redis do
        puts 'Registered sensors to be reduced'
        puts all_sensors_table
        PulseMeter::Sensor::Timeline.reduce_all_raw
        puts "DONE"
      end
    end

    desc "event NAME VALUE", "Send event VALUE to sensor NAME"
    common_options
    method_option :format, :default => :plain, :desc => "Event format: plain or json"
    def event(name, value)
      if "json" == options[:format]
        value = JSON.parse(value)
      end
      with_safe_restore_of(name) {|sensor|
        sensor.event(value)
      }
      PulseMeter.command_aggregator.wait_for_pending_events
    end

    desc "timeline NAME SECONDS", "Get sensor's NAME timeline for last SECONDS"
    common_options
    method_option :format, :default => :table, :desc => "Output format: table or csv"
    def timeline(name, seconds)
      with_safe_restore_of(name) do |sensor|
        now = Time.now
        puts sensor.
          timeline_within(now - seconds, now, true).
          map {|data| [data.start_time, data.value || '']}.
          to_table(options[:format])
      end
    end

    desc "timeline_within NAME FROM TILL", "Get sensor's NAME timeline in interval. Time format: YYYY-MM-DD HH:MM:SS"
    common_options
    method_option :format, :default => :table, :desc => "Output format: table or csv"
    def timeline_within(name, from, till, true)
      with_safe_restore_of(name) do |sensor|
        puts sensor.
          timeline_within(Time.parse(from), Time.parse(till)).
          map {|data| [data.start_time, data.value || '']}.
          to_table(options[:format])
      end
    end

    desc "delete NAME", "Delete sensor by name"
    common_options
    def delete(name)
      with_safe_restore_of(name) {|sensor| sensor.cleanup}
      puts "Sensor #{name} deleted"
    end

    desc "create NAME TYPE", "Create sensor of given type"
    common_options
    sensor_options([:ttl, :interval])
    def create(name, type)
      with_redis do
        klass = constantize("PulseMeter::Sensor::Timelined::#{type}")
        puts "PulseMeter::Sensor::Timelined::#{type}"
        fail! "Unknown sensor type #{type}" unless klass
        sensor = klass.new(name, options.dup)
        puts "Sensor created"
        puts all_sensors_table
      end
    end

    desc "update NAME", "Update given sensor"
    common_options
    sensor_options
    def update(name)
      with_safe_restore_of(name) do |sensor|
        opts = options.dup
        [:ttl, :interval, :reduce_delay, :raw_data_ttl, :annotation].each do |attr|
          opts[attr] ||= sensor.send(attr)
        end
        klass = sensor.class
        new_sensor = klass.new(name, opts)
        new_sensor.dump!(false)
        puts "Sensor updated"
        puts all_sensors_table
      end
    end

    desc "create_simple NAME TYPE", "Create simple non-timelined sensor of given type"
    common_options
    method_option :annotation, :type => :string, :desc => "Sensor annotation"
    def create_simple(name, type)
      with_redis do
        klass = constantize("PulseMeter::Sensor::#{type}")
        fail! "Unknown sensor type #{type}" unless klass
        sensor = klass.new(name, options.dup)
        puts "Sensor created"
        puts all_sensors_table
      end
    end

    desc "value NAME", "Get value of non-timelined sensor"
    def value(name)
      with_safe_restore_of(name) do |sensor|
        fail! "Sensor #{name} has no value method" unless sensor.respond_to?(:value)
        puts "Value: #{sensor.value}"
      end
    end

    desc "drop NAME DATE_FROM(YYYYmmddHHMMSS) DATE_TO(YYYYmmddHHMMSS)", "Drop timeline data of a particular sensor"
    common_options
    def drop(name, from, to)
      time_from = parse_time(from)
      time_to = parse_time(to)
      with_safe_restore_of(name) do |sensor|
        fail! "Sensor #{name} has no drop_within method" unless sensor.respond_to?(:drop_within)
        sensor.drop_within(time_from, time_to)
      end
    end

    desc "udp_proxy HOST PORT", "Start UDP proxy for sensor data"
    common_options
    def udp_proxy(host, port)
      with_redis do
        puts 'Starting UDP server'
        server = PulseMeter::UDPServer.new(host, port)
        server.start
      end
    end

  end
end
