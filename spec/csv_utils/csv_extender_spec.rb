# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVExtender do
  let(:src_headers) { %w[id name] }
  let(:src_rows) do
    [
      %w[3 four],
      %w[9 ten],
      %w[19 twenty]
    ]
  end
  let(:csv_file) do
    'csv_extender_src_file.csv'.tap do |file|
      CSV.open(file, 'wb') do |csv|
        csv << src_headers if src_headers
        src_rows.each { |row| csv << row }
      end
    end
  end
  let(:new_csv_file) { 'csv_extender_dest_file.csv' }
  let(:csv_options) { {} }
  let(:csv_extender) { CSVUtils::CSVExtender.new(csv_file, new_csv_file, csv_options) }

  after do
    FileUtils.rm_f(csv_file)
    FileUtils.rm_f(new_csv_file)
  end

  context 'append' do
    let(:additional_headers) { ['count1'] }
    subject { csv_extender.append(additional_headers) { |_row, _headers| [1] } }
    let(:expected_new_csv) do
      [
        src_headers + additional_headers
      ] + src_rows.map { |row| row + ['1'] }
    end
    before { subject }

    it { expect(CSV.read(new_csv_file)).to eq(expected_new_csv) }
  end

  context 'append_in_batches' do
    let(:additional_headers) { ['count1'] }
    subject { csv_extender.append_in_batches(additional_headers) { |batch, _headers| batch.map { [1] } } }
    let(:expected_new_csv) do
      [
        src_headers + additional_headers
      ] + src_rows.map { |row| row + ['1'] }
    end
    before { subject }

    it { expect(CSV.read(new_csv_file)).to eq(expected_new_csv) }

    describe 'with batches that divide the rows evenly' do
      let(:batches) { [] }
      subject do
        csv_extender.append_in_batches(additional_headers, 1) do |batch, _headers|
          batches << batch.size
          batch.map { [1] }
        end
      end

      it { expect(CSV.read(new_csv_file)).to eq(expected_new_csv) }
      it { expect(batches).to eq([1, 1, 1]) }
    end
  end

  context 'append to a file without headers' do
    let(:src_headers) { nil }
    subject { csv_extender.append(nil) { |row, headers| [headers.inspect, row[0].to_i * 2] } }
    before { subject }

    it 'extends every row and passes nil headers' do
      expect(CSV.read(new_csv_file)).to eq([%w[3 four nil 6], %w[9 ten nil 18], %w[19 twenty nil 38]])
    end
  end

  context 'when the block raises' do
    it 'closes both files' do
      expect { csv_extender.append(['count1']) { raise 'boom' } }.to raise_error('boom')
      expect(csv_extender.instance_variable_get(:@src_csv).csv).to be_closed
      expect(csv_extender.instance_variable_get(:@dest_csv).csv).to be_closed
    end
  end
end
