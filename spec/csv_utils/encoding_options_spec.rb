# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::EncodingOptions do
  describe '.read' do
    it 'defaults the encoding' do
      expect(described_class.read(col_sep: "\t")).to eq(encoding: 'bom|utf-8', col_sep: "\t")
    end

    it 'keeps a given encoding' do
      expect(described_class.read(encoding: 'BINARY')).to eq(encoding: 'BINARY')
    end
  end

  describe '.write' do
    {
      nil => 'utf-8',
      'bom|utf-8' => 'utf-8',
      'Windows-1252:UTF-8' => 'UTF-8',
      'BOM|UTF-16LE:UTF-8' => 'UTF-8',
      'BINARY' => 'BINARY',
      'ISO-8859-1' => 'ISO-8859-1',
      Encoding::BINARY => 'ASCII-8BIT'
    }.each do |read_encoding, write_encoding|
      it "writes #{write_encoding} for values read with #{read_encoding.inspect}" do
        csv_options = { col_sep: '|' }
        csv_options[:encoding] = read_encoding if read_encoding
        expect(described_class.write(csv_options)).to eq(col_sep: '|', encoding: write_encoding)
      end
    end
  end

  describe 'round trip through CSV' do
    let(:src) { 'encoding_options_src.csv' }
    let(:dest) { 'encoding_options_dest.csv' }

    after { FileUtils.rm_f([src, dest]) }

    {
      'Windows-1252:UTF-8' => ["caf\xE9\n".b, "caf\u00E9\n".b],
      'BINARY' => ["caf\xE9\n".b, "caf\xE9\n".b],
      'BOM|UTF-16LE:UTF-8' => ["\xFF\xFE".b + "caf\u00E9\n".encode('UTF-16LE').b, "caf\u00E9\n".b],
      'bom|utf-8' => ["\xEF\xBB\xBFcaf\u00E9\n".b, "caf\u00E9\n".b]
    }.each do |encoding, (input, output)|
      it "reads #{encoding} and writes the decoded values" do
        File.binwrite(src, input)
        rows = CSV.open(src, 'rb', **described_class.read(encoding: encoding), &:to_a)
        CSV.open(dest, 'wb', **described_class.write(encoding: encoding)) { |csv| rows.each { |row| csv << row } }
        expect(File.binread(dest)).to eq(output)
        expect(CSV.open(dest, 'rb', **described_class.write(encoding: encoding), &:to_a)).to eq(rows)
      end
    end
  end
end
