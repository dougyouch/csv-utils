# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVIterator do
  let(:test_file) { 'csv_iterator_test.csv' }
  let(:headers) { %w[id name value] }
  let(:rows) do
    [
      %w[1 alpha 100],
      %w[2 beta 200],
      %w[3 gamma 300]
    ]
  end

  before do
    CSV.open(test_file, 'wb') do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  after do
    FileUtils.rm_f(test_file)
  end

  describe CSVUtils::CSVIterator::RowWrapper do
    describe '.create' do
      subject { described_class.create(headers, rows[0], 2) }

      it 'creates a hash from headers and row values' do
        expect(subject['id']).to eq('1')
        expect(subject['name']).to eq('alpha')
        expect(subject['value']).to eq('100')
      end

      it 'sets the line number' do
        expect(subject.lineno).to eq(2)
      end
    end

    describe '#to_pretty_s' do
      let(:row_data) { ['1', 'alpha', nil, '', '  '] }
      let(:row_headers) { %w[id name empty1 empty2 whitespace] }
      subject { described_class.create(row_headers, row_data, 1) }

      it 'formats non-empty values with indices' do
        result = subject.to_pretty_s
        expect(result).to include('id: 1')
        expect(result).to include('name: alpha')
        expect(result).not_to include('empty1')
        expect(result).not_to include('empty2')
        expect(result).not_to include('whitespace')
      end
    end
  end

  describe '#initialize' do
    it 'creates an iterator from a file path' do
      iterator = described_class.new(test_file)
      expect(iterator.headers).to eq(headers)
    end
  end

  describe '#each' do
    subject { described_class.new(test_file) }

    it 'yields RowWrapper objects for each data row' do
      yielded_rows = subject.map { |row| row }

      expect(yielded_rows.size).to eq(3)
      expect(yielded_rows[0]).to be_a(CSVUtils::CSVIterator::RowWrapper)
      expect(yielded_rows[0]['id']).to eq('1')
      expect(yielded_rows[1]['name']).to eq('beta')
      expect(yielded_rows[2]['value']).to eq('300')
    end

    it 'sets correct line numbers' do
      line_numbers = subject.map(&:lineno)

      expect(line_numbers).to eq([2, 3, 4])
    end

    it 'tracks prev_row' do
      subject.each { |_| }
      expect(subject.prev_row).to eq(rows.last)
    end

    it 'can be called multiple times (rewinds)' do
      first_pass = subject.map { |row| row['id'] }

      second_pass = subject.map { |row| row['id'] }

      expect(first_pass).to eq(second_pass)
    end

    context 'with custom headers' do
      let(:custom_headers) { %w[col1 col2 col3] }

      it 'uses provided headers instead of reading from file' do
        yielded_rows = []
        subject.each(custom_headers) { |row| yielded_rows << row }

        expect(yielded_rows.size).to eq(4)
        expect(yielded_rows[0]['col1']).to eq('id')
        expect(yielded_rows[1]['col1']).to eq('1')
      end
    end
  end

  describe '#headers' do
    subject { described_class.new(test_file) }

    it 'returns the header row' do
      expect(subject.headers).to eq(headers)
    end

    it 'can be called multiple times' do
      expect(subject.headers).to eq(headers)
      expect(subject.headers).to eq(headers)
    end
  end

  describe '#to_hash' do
    subject { described_class.new(test_file) }

    context 'with key and value columns' do
      it 'creates a hash mapping key to value' do
        result = subject.to_hash('id', 'name')

        expect(result).to eq({
                               '1' => 'alpha',
                               '2' => 'beta',
                               '3' => 'gamma'
                             })
      end
    end

    context 'with key and block' do
      it 'creates a hash mapping key to block result' do
        result = subject.to_hash('name') { |row| row['value'].to_i * 2 }

        expect(result).to eq({
                               'alpha' => 200,
                               'beta' => 400,
                               'gamma' => 600
                             })
      end
    end

    context 'with invalid key' do
      it 'raises an error' do
        expect { subject.to_hash('invalid', 'name') }.to raise_error(/header invalid not found/)
      end
    end

    context 'with invalid value column' do
      it 'raises an error' do
        expect { subject.to_hash('id', 'invalid') }.to raise_error(/headers invalid not found/)
      end
    end
  end

  describe '#size' do
    subject { described_class.new(test_file) }

    it 'returns the count of data rows (excluding header)' do
      expect(subject.size).to eq(3)
    end
  end

  describe '#each_batch' do
    subject { described_class.new(test_file) }

    context 'with batch size larger than data' do
      it 'yields a single batch' do
        batches = []
        subject.each_batch(10) { |batch| batches << batch.dup }

        expect(batches.size).to eq(1)
        expect(batches[0].size).to eq(3)
      end
    end

    context 'with batch size smaller than data' do
      it 'yields multiple batches' do
        batches = []
        subject.each_batch(2) { |batch| batches << batch.dup }

        expect(batches.size).to eq(2)
        expect(batches[0].size).to eq(2)
        expect(batches[1].size).to eq(1)
      end
    end

    context 'with exact batch size' do
      it 'yields exactly matching batches' do
        batches = []
        subject.each_batch(3) { |batch| batches << batch.dup }

        expect(batches.size).to eq(1)
        expect(batches[0].size).to eq(3)
      end
    end

    it 'returns nil' do
      result = subject.each_batch { |_| }
      expect(result).to be_nil
    end
  end

  describe 'Enumerable support' do
    subject { described_class.new(test_file) }

    it 'supports map' do
      ids = subject.map { |row| row['id'] }
      expect(ids).to eq(%w[1 2 3])
    end

    it 'supports select' do
      selected = subject.select { |row| row['value'].to_i > 150 }
      expect(selected.size).to eq(2)
    end

    it 'supports first' do
      first = subject.first
      expect(first['id']).to eq('1')
    end
  end

  describe 'BOM stripping' do
    let(:bom_file) { 'csv_iterator_bom_test.csv' }
    let(:bom_bytes) { (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT') }

    before do
      File.open(bom_file, 'wb') do |f|
        f.write(bom_bytes)
        f.write("id,name\n1,test\n")
      end
    end

    after do
      FileUtils.rm_f(bom_file)
    end

    context 'in binary mode' do
      subject { described_class.new(bom_file, { encoding: 'ASCII-8BIT' }, 'rb') }

      it 'strips UTF-8 BOM from first header' do
        headers = subject.headers
        expect(headers.first).not_to start_with(bom_bytes)
        expect(headers.first).to eq('id')
      end

      it 'strips BOM when iterating with each' do
        subject.each do |row|
          expect(row.keys.first).to eq('id')
          expect(row.keys.first).not_to start_with(bom_bytes)
        end
      end

      it 'allows correct data access after BOM stripping' do
        subject.each do |row|
          expect(row['id']).not_to be_nil
        end
      end
    end
  end

  describe 'empty file handling' do
    let(:empty_file) { 'csv_iterator_empty_test.csv' }

    before do
      CSV.open(empty_file, 'wb') do |csv|
        csv << headers
      end
    end

    after do
      FileUtils.rm_f(empty_file)
    end

    subject { described_class.new(empty_file) }

    it 'returns empty for each' do
      yielded = subject.map { |row| row }
      expect(yielded).to be_empty
    end

    it 'returns 0 for size' do
      expect(subject.size).to eq(0)
    end

    it 'returns headers correctly' do
      expect(subject.headers).to eq(headers)
    end
  end
end
