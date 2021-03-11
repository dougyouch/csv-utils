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
  let(:first_heading) { byte_order_mark + 'ID' }
  let(:headings) { [first_heading, 'Name'] }
  let(:csv_row) { headings.map { |_| SecureRandom.uuid } }
  let(:csv) do
    CSV.generate(**options) do |csv|
      csv << headings
      csv << csv_row
    end.force_encoding('ASCII-8BIT')
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
      let(:byte_order_mark) { "\xEF\xBB\xBF".force_encoding('ASCII-8BIT') }

      it { is_expected.to eq('UTF-8') }
    end
  end

  context 'columns' do
    subject { csv_options.columns }
    let(:byte_order_mark) { "\xEF\xBB\xBF".force_encoding('ASCII-8BIT') }

    it { is_expected.to eq(2) }
  end
end
