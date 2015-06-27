require 'spec_helper'

describe PulseMeter::Mixins::Cmd do
  class CmdDummy
    include PulseMeter::Mixins::Cmd

    def initialize(redis)
      @redis = redis
    end

    def create_redis
      @redis
    end
  end

  let(:redis){ MockRedis.new }
  let(:dummy){ CmdDummy.new(redis) }
  before{ PulseMeter.redis = redis }

  describe "#fail!" do
    it "prints given message and exits" do
      expect(STDOUT).to receive(:puts).with(:msg)
      expect {dummy.fail!(:msg)}.to raise_error(SystemExit)
    end
  end

  describe '#with_redis' do
    it "initializes redies and yields a block" do
      PulseMeter.redis = nil
      dummy.with_redis do
        expect(PulseMeter.redis).not_to be_nil
      end
    end
  end

  describe "#with_safe_restore_of" do
    it "restores sensor by name and passes it to block" do
      sensor = PulseMeter::Sensor::Counter.new(:foo)
      dummy.with_safe_restore_of(:foo) do |s|
        expect(s).to be_instance_of(sensor.class)
      end
    end

    it "prints error and exits if sensor cannot be restored" do
      expect(STDOUT).to receive(:puts).with("Sensor nonexistant is unknown or cannot be restored")
      expect {dummy.with_safe_restore_of(:nonexistant) {|s| s}}.to raise_error(SystemExit)
    end
  end

  describe "#all_sensors" do
    it "is just an alias to PulseMeter::Sensor::Timeline.list_objects" do
      expect(PulseMeter::Sensor::Timeline).to receive(:list_objects)
      dummy.all_sensors
    end
  end

  describe "#all_sensors_table" do
    before {PulseMeter.redis.flushall}
    let(:init_values){ {:ttl => 1, :raw_data_ttl => 2, :interval => 3, :reduce_delay => 4} }
    let!(:s1) {PulseMeter::Sensor::Counter.new(:s1)} 
    let!(:s2) {PulseMeter::Sensor::Timelined::Counter.new(:s2, init_values)} 
    let!(:table) {dummy.all_sensors_table}
    let!(:csv) {dummy.all_sensors_table(:csv)}
    let!(:parsed_csv) {CSV.parse(csv, col_sep: ";")}

    def rows(format)
      if "csv" == format.to_s
        parsed_csv
      else
        table.rows.map do |row|
          row.cells.map(&:to_s).map(&:strip)
        end
      end
    end

    def sensor_row(name, format)
      rows(format).select {|row| row[0] == name}.first
    end
      
    [:csv, :table].each do |format|
      context "when format is #{format}" do

        if "csv" == format.to_s
          it "returns csv as string" do
            expect(csv).to be_instance_of(String)
          end
        else
          it "returns Terminal::Table instance" do
            expect(table).to be_instance_of(Terminal::Table)
          end
        end

        it "has title row" do
          expect(rows(format)[0]).to eq(["Name", "Class", "ttl", "raw data ttl", "interval", "reduce delay"])
        end

        it "has one row for each sensor (and a title)" do
          expect(rows(format).count).to eq(3)
        end

        it "can display timelined sensors" do
          expect(sensor_row("s2", format)).to eq([
            s2.name, s2.class, s2.ttl, s2.raw_data_ttl, s2.interval, s2.reduce_delay
          ].map(&:to_s))
        end

        it "can display static sensors" do
          expect(sensor_row("s1", format)).to eq([
            s1.name, s1.class, "", "", "", ""
          ].map(&:to_s))
        end

      end
    end
  end

end
