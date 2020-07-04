require 'spec_helper'

describe CSVUtils::CSVExtender do
  let(:src_headers) { ['id', 'name'] }
  let(:src_rows) do
    [
      ['3', 'four'],
      ['9', 'ten'],
      ['19', 'twenty']
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
    File.unlink(csv_file) if File.exist?(csv_file)
    File.unlink(new_csv_file) if File.exist?(new_csv_file)
  end

  context 'append' do
    let(:additional_headers) { ['count1'] }
    subject { csv_extender.append(additional_headers) { |row, headers| [1] } }
    let(:expected_new_csv) do
      [
        (src_headers + additional_headers),
      ] + src_rows.map { |row| row + ['1'] }
    end
    before { subject }

    it { expect(CSV.read(new_csv_file)).to eq(expected_new_csv) }
  end

  context 'append_in_batches' do
    let(:additional_headers) { ['count1'] }
    subject { csv_extender.append_in_batches(additional_headers) { |batch, headers| batch.map { [1] } } }
    let(:expected_new_csv) do
      [
        (src_headers + additional_headers),
      ] + src_rows.map { |row| row + ['1'] }
    end
    before { subject }

    it { expect(CSV.read(new_csv_file)).to eq(expected_new_csv) }
  end
end

