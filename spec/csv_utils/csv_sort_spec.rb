# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVSort do
  let(:random_numbers) do
    100_000.times.map do
      rand(1_000_000)
    end
  end
  let(:csv_file) do
    file = 'csv_utils_csv_sort_spec.csv'
    CSV.open(file, 'wb') do |csv|
      csv << ['num']
      random_numbers.each { |num| csv << [num] }
    end
    file
  end
  let(:new_csv_file) { 'csv_utils_csv_sort_spec.sorted.csv' }
  let(:new_csv_nums) do
    rows = CSV.read(new_csv_file)
    rows.shift
    rows.map! { |row| row.first.to_i }
  end
  let(:has_headers) { true }
  let(:csv_options) { {} }
  let(:csv_sorter) { CSVUtils::CSVSort.new(csv_file, new_csv_file, has_headers, csv_options) }

  after do
    FileUtils.rm_f(csv_file)
    FileUtils.rm_f(new_csv_file)
  end

  context 'sort' do
    let(:batch_size) { 20_000 }
    subject { csv_sorter.sort(batch_size) { |a, b| a.first.to_i <=> b.first.to_i } }

    before { subject }

    it { expect(new_csv_nums).to eq(random_numbers.sort) }

    describe 'empty csv file' do
      let(:random_numbers) { [] }

      before { subject }

      it { expect(new_csv_nums).to eq(random_numbers.sort) }
    end
  end
end
