# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVOptions do
  let(:col_sep) { ',' }
  let(:row_sep) { "\n" }
  let(:options) do
    {
      col_sep: col_sep,
      row_sep: row_sep
    }
  end
  let(:byte_order_mark) { '' }
  let(:first_heading) { "#{byte_order_mark}ID" }
  let(:headings) { [first_heading, 'Name'] }
  let(:csv_row) { headings.map { |_| SecureRandom.uuid } }
  let(:csv) do
    CSV.generate(**options) do |csv|
      csv << headings
      csv << csv_row
    end.dup.force_encoding('ASCII-8BIT')
  end
  let(:io) { StringIO.new(csv) }
  let(:csv_options) { CSVUtils::CSVOptions.new(io) }

  context 'valid?' do
    subject { csv_options.valid? }

    it { is_expected.to eq(true) }

    describe 'unknown col_sep' do
      let(:col_sep) { '#' }

      it { is_expected.to eq(false) }
      it { expect(csv_options.col_separator).to eq(nil) }
    end

    describe 'unknown row_sep' do
      let(:row_sep) { '?' }

      it { is_expected.to eq(false) }
      it { expect(csv_options.row_separator).to eq(nil) }
    end
  end

  context 'encoding' do
    subject { csv_options.encoding }

    it { is_expected.to eq('UTF-8') }

    describe 'with UTF-8 byte order mark' do
      let(:byte_order_mark) { (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT') }

      it { is_expected.to eq('UTF-8') }
    end

    describe 'with UTF-32 LE byte order mark' do
      let(:byte_order_mark) { (+"\xFF\xFE\x00\x00").force_encoding('ASCII-8BIT') }

      it { is_expected.to eq('UTF-32') }
      it { expect(csv_options.byte_order_mark).to eq(byte_order_mark) }
    end

    describe 'with UTF-16 LE byte order mark' do
      let(:byte_order_mark) { (+"\xFF\xFE").force_encoding('ASCII-8BIT') }

      it { is_expected.to eq('UTF-16') }
    end

    describe 'reading a utf-8 io with non-ascii headers' do
      let(:io) { StringIO.new("été,Name\n1,2\n") }

      it { is_expected.to eq('UTF-8') }
      it { expect(csv_options.columns).to eq(2) }
    end
  end

  context 'columns' do
    subject { csv_options.columns }
    let(:byte_order_mark) { (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT') }

    it { is_expected.to eq(2) }
  end

  context 'get_headers' do
    subject { csv_options.get_headers(line) }

    let(:line) { "#{byte_order_mark}id,\"last, first\",,age\n" }

    it { is_expected.to eq(['id', 'last, first', nil, 'age']) }

    describe 'with a byte order mark' do
      let(:byte_order_mark) { (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT') }
      let(:line) { "#{byte_order_mark}id,name\n".b }

      it { is_expected.to eq(%w[id name]) }
    end

    describe 'with a malformed quote' do
      let(:line) { "id,na\"me,age\n" }

      it { is_expected.to eq(['id', 'na"me', 'age']) }
    end

    describe 'without a row separator' do
      let(:io) { StringIO.new('id,name') }
      let(:line) { 'id,"name' }

      it { is_expected.to eq(['id', '"name']) }
    end
  end

  context 'with quoted separators in the headers' do
    let(:headings) { ['ID', 'Last, First', 'Age'] }

    it { expect(csv_options.columns).to eq(3) }
  end

  context 'with carriage return row separators' do
    let(:row_sep) { "\r" }

    it { expect(csv_options.row_separator).to eq("\r") }
    it { expect(csv_options.columns).to eq(2) }
  end

  context 'with an empty file' do
    let(:io) { StringIO.new('') }

    it { expect(csv_options.valid?).to eq(false) }
    it { expect(csv_options.columns).to be_nil }
    it { expect(csv_options.encoding).to eq('UTF-8') }
  end

  context 'with a file path' do
    let(:file) { 'csv_options_spec.csv' }
    let(:csv_options) { CSVUtils::CSVOptions.new(file) }

    before { File.binwrite(file, csv) }
    after { FileUtils.rm_f(file) }

    it { expect(csv_options.columns).to eq(2) }

    describe 'that is empty' do
      let(:csv) { '' }

      it { expect(csv_options.valid?).to eq(false) }
    end
  end

  context 'to_csv_options' do
    subject { csv_options.to_csv_options }

    it { is_expected.to eq(col_sep: ',', row_sep: "\n") }

    describe 'with tabs and carriage returns' do
      let(:col_sep) { "\t" }
      let(:row_sep) { "\r\n" }

      it { is_expected.to eq(col_sep: "\t", row_sep: "\r\n") }
    end

    describe 'without detected separators' do
      let(:io) { StringIO.new('id') }

      it { is_expected.to eq({}) }
    end

    describe 'with a UTF-16 byte order mark' do
      let(:byte_order_mark) { (+"\xFF\xFE").force_encoding('ASCII-8BIT') }

      it 'leaves the row separator to CSV' do
        is_expected.to eq(col_sep: ',')
      end
    end
  end

  context 'mode' do
    subject { csv_options.mode }

    it { is_expected.to eq('rb') }

    {
      "\xEF\xBB\xBF" => 'rb',
      "\xFF\xFE" => 'rb:BOM|UTF-16LE:UTF-8',
      "\xFE\xFF" => 'rb:BOM|UTF-16BE:UTF-8',
      "\xFF\xFE\x00\x00" => 'rb:BOM|UTF-32LE:UTF-8',
      "\x00\x00\xFE\xFF" => 'rb:BOM|UTF-32BE:UTF-8'
    }.each do |bom, mode|
      describe "with the byte order mark #{bom.b.inspect}" do
        let(:byte_order_mark) { bom.b }

        it { is_expected.to eq(mode) }
      end
    end
  end
end
