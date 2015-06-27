require 'spec_helper'
require 'pulse_meter/extensions/enumerable'

describe Enumerable do
  let!(:time) {Time.new}
  describe "#convert_time" do
    it "converts Time objects to unixtime" do
      expect([time].convert_time).to eq([time.to_i])
    end

    it "does not change other members" do
      expect([1, 2, 3].convert_time).to eq([1, 2 ,3])
    end
  end

  describe "#to_table" do
    context "when format is csv" do
      it "returns csv as string" do
        expect([].to_table(:csv)).to be_instance_of(String)
      end

      it "returns csv containing each subarray as a row" do
        expect([[:a, :b], [:c, :d]].to_table(:csv)).to eq("a;b\nc;d\n")
      end

      it "converts Time objects to unixtime" do
        expect([[time]].to_table(:csv)).to eq("#{time.to_i}\n")
      end

      it "takes format argument both as string and as symbol" do
        expect([[:foo]].to_table("csv")).to eq("foo\n")
        expect([[:foo]].to_table(:csv)).to eq("foo\n")
      end
    end

    context "when format is table" do
      it "return Terminal::Table instance" do
        expect([].to_table).to be_instance_of(Terminal::Table)
      end

      it "returns table containing each subarray as a row" do
        data = [[:a, :b], [:c, :d]]
        table = [[:a, :b], [:c, :d]].to_table
        expect(table.rows.map do |row|
          row.cells.map(&:to_s).map(&:strip).map(&:to_sym)
        end).to eq(data)
      end
    end

    it "uses table format as default" do
      expect([].to_table).to be_instance_of(Terminal::Table)
    end

    it "uses table format unless it is :csv or 'csv'" do
      expect([].to_table(:unknown_format)).to be_instance_of(Terminal::Table)
    end
  end
end
