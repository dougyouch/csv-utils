# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVSort do
  let(:random_numbers) do
    1_000.times.map do
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
    let(:batch_size) { 200 }
    subject { csv_sorter.sort(batch_size) { |a, b| a.first.to_i <=> b.first.to_i } }

    before { subject }

    it { expect(new_csv_nums).to eq(random_numbers.sort) }

    describe 'empty csv file' do
      let(:random_numbers) { [] }

      before { subject }

      it { expect(new_csv_nums).to eq(random_numbers.sort) }
    end
  end

  context 'encodings' do
    let(:csv_file) do
      file = 'csv_utils_csv_sort_spec.csv'
      File.binwrite(file, content)
      file
    end

    describe 'with a Windows-1252 file' do
      let(:content) { "name\nz\xE9\ncaf\xE9\nb\n".b }
      let(:csv_options) { { encoding: 'Windows-1252:UTF-8' } }

      it 'reads with the encoding and writes the decoded UTF-8' do
        csv_sorter.sort(1)
        expect(File.binread(new_csv_file)).to eq("name\nb\ncaf\u00E9\nz\u00E9\n".b)
      end
    end

    describe 'with a headers only file' do
      let(:content) { "\xEF\xBB\xBFname\n".b }

      it 'writes the headers rather than copying the file' do
        csv_sorter.sort
        expect(File.binread(new_csv_file)).to eq("name\n".b)
      end
    end

    describe 'with an empty file and no headers' do
      let(:content) { '' }
      let(:has_headers) { false }

      it 'writes an empty file' do
        csv_sorter.sort
        expect(File.binread(new_csv_file)).to eq('')
      end
    end
  end

  context 'sort without a block' do
    let(:random_numbers) { %w[b d a c e] }

    before { csv_sorter.sort(2) }

    it 'compares rows as arrays of strings across part files' do
      expect(CSV.read(new_csv_file)).to eq([['num']] + %w[a b c d e].map { |num| [num] })
    end

    it 'leaves no temporary files behind' do
      expect(Dir["#{new_csv_file}.*"]).to eq([])
    end
  end

  context 'when the comparison raises' do
    let(:random_numbers) { [3, 1, 2, 5, 4] }

    it 'removes the part and merge files' do
      part_files = []
      comparisons = 0
      expect do
        csv_sorter.sort(2) do |a, b|
          comparisons += 1
          # the batches of 2 take 2 comparisons, so this fails while merging the part files
          part_files = Dir["#{new_csv_file}.*"] if comparisons == 3
          raise 'boom' if comparisons == 4

          a.first.to_i <=> b.first.to_i
        end
      end.to raise_error('boom')
      expect(part_files).not_to be_empty
      expect(Dir["#{new_csv_file}.*"]).to eq([])
    end
  end

  context 'sorting twice' do
    let(:random_numbers) { [3, 1, 2] }

    it 'starts each sort fresh' do
      2.times { csv_sorter.sort(2) { |a, b| a.first.to_i <=> b.first.to_i } }
      expect(new_csv_nums).to eq([1, 2, 3])
    end
  end

  context 'sort without headers' do
    let(:csv_file) do
      'csv_utils_csv_sort_spec.csv'.tap do |file|
        CSV.open(file, 'wb') { |csv| [5, 3, 4, 1, 2].each { |num| csv << [num] } }
      end
    end
    let(:has_headers) { false }

    before { csv_sorter.sort(2) { |a, b| a.first.to_i <=> b.first.to_i } }

    it 'sorts every row and adds no header' do
      expect(CSV.read(new_csv_file).flatten).to eq(%w[1 2 3 4 5])
    end

    it { expect(csv_sorter.headers).to be_nil }
  end
end
