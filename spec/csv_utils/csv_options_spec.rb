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
end
