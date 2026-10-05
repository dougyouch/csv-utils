# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVCompare do
  let(:csv_file1) do
    csv_file = 'csv_file1_spec.csv'
    CSV.open(csv_file, 'wb') do |csv|
      csv << %w[id name date]
      csv << [8, 'test1', '2018-01-09']
      csv << [2, 'test2', '2019-10-12']
      csv << [5, 'test5', '2016-07-21']
      csv << [7, 'test7', '2020-04-13']
      csv << [12, 'test12', '2015-01-12']
      csv << [11, 'test11', '2011-03-21']
    end
    sorted_csv_file = 'csv_file1_spec.sorted.csv'
    csv_sort = CSVUtils::CSVSort.new(csv_file, sorted_csv_file)
    csv_sort.sort { |a, b| a[0].to_i <=> b[0].to_i }
    File.unlink(csv_file)
    sorted_csv_file
  end

  let(:csv_file2) do
    csv_file = 'csv_file2_spec.csv'
    CSV.open(csv_file, 'wb') do |csv|
      csv << %w[ID NameType Valid date]
      csv << [8, 'test1', 'Y', '2018-01-09']
      csv << [5, 'test5', 'Y', '2016-07-21']
      csv << [10, 'test10', 'N', '2014-02-05']
      csv << [7, 'test7', 'Y', '2019-12-30']
    end
    sorted_csv_file = 'csv_file2_spec.sorted.csv'
    csv_sort = CSVUtils::CSVSort.new(csv_file, sorted_csv_file)
    csv_sort.sort { |a, b| a[0].to_i <=> b[0].to_i }
    File.unlink(csv_file)
    sorted_csv_file
  end

  let(:primary_data_file) { csv_file1 }
  let(:secondary_data_file) { csv_file2 }
  let(:update_comparison_columns) { ['date'] }
  let(:csv_compare) { CSVUtils::CSVCompare.new(primary_data_file, update_comparison_columns) { |src, dest| src['id'].to_i <=> dest['ID'].to_i } }
  let(:compare_results) do
    results = []
    csv_compare.compare(secondary_data_file) do |action, record|
      results << [action, record]
    end
    results
  end

  after do
    FileUtils.rm_f(csv_file1)
    FileUtils.rm_f(csv_file2)
  end

  context 'compare' do
    let(:expected_compare_results) do
      [
        [:create, { 'date' => '2019-10-12', 'id' => '2', 'name' => 'test2' }],
        [:update, { 'date' => '2020-04-13', 'id' => '7', 'name' => 'test7' }],
        [:delete, { 'ID' => '10', 'NameType' => 'test10', 'Valid' => 'N', 'date' => '2014-02-05' }],
        [:create, { 'date' => '2011-03-21', 'id' => '11', 'name' => 'test11' }],
        [:create, { 'date' => '2015-01-12', 'id' => '12', 'name' => 'test12' }]
      ]
    end

    it { expect(compare_results).to eq(expected_compare_results) }

    describe 'swap files' do
      let(:primary_data_file) { csv_file2 }
      let(:secondary_data_file) { csv_file1 }
      let(:csv_compare) { CSVUtils::CSVCompare.new(primary_data_file, update_comparison_columns) { |src, dest| src['ID'].to_i <=> dest['id'].to_i } }
      let(:expected_compare_results) do
        [
          [:delete, { 'date' => '2019-10-12', 'id' => '2', 'name' => 'test2' }],
          [:update, { 'ID' => '7', 'NameType' => 'test7', 'Valid' => 'Y', 'date' => '2019-12-30' }],
          [:create, { 'ID' => '10', 'NameType' => 'test10', 'Valid' => 'N', 'date' => '2014-02-05' }],
          [:delete, { 'date' => '2011-03-21', 'id' => '11', 'name' => 'test11' }],
          [:delete, { 'date' => '2015-01-12', 'id' => '12', 'name' => 'test12' }]
        ]
      end

      it { expect(compare_results).to eq(expected_compare_results) }
    end
  end

  context 'when one file runs out with a single record left in the other' do
    let(:primary_rows) { [%w[1 a], %w[3 c]] }
    let(:secondary_rows) { [%w[2 b]] }
    let(:csv_file1) { write_csv('csv_file1_spec.csv', primary_rows) }
    let(:csv_file2) { write_csv('csv_file2_spec.csv', secondary_rows) }
    let(:csv_compare) { CSVUtils::CSVCompare.new(primary_data_file) { |src, dest| src['id'].to_i <=> dest['id'].to_i } }

    def write_csv(file, rows)
      CSV.open(file, 'wb') do |csv|
        csv << %w[id name]
        rows.each { |row| csv << row }
      end
      file
    end

    it 'yields the last primary record' do
      expect(compare_results.map { |action, record| [action, record['id']] }).to eq(
        [[:create, '1'], [:delete, '2'], [:create, '3']]
      )
    end

    describe 'secondary record left over' do
      let(:primary_rows) { [%w[2 b]] }
      let(:secondary_rows) { [%w[1 a], %w[3 c]] }

      it 'yields the last secondary record' do
        expect(compare_results.map { |action, record| [action, record['id']] }).to eq(
          [[:delete, '1'], [:create, '2'], [:delete, '3']]
        )
      end
    end

    describe 'without update comparison columns' do
      let(:secondary_rows) { [%w[1 changed], %w[3 c]] }

      it 'never yields updates' do
        expect(compare_results.map(&:first)).to eq([])
      end
    end

    describe 'empty secondary file' do
      let(:csv_file2) { File.write('csv_file2_spec.csv', '') && 'csv_file2_spec.csv' }

      it 'creates every primary record' do
        expect(compare_results.map { |action, record| [action, record['id']] }).to eq([[:create, '1'], [:create, '3']])
      end
    end

    describe 'utf-8 byte order mark before the first header' do
      let(:csv_file1) do
        File.binwrite('csv_file1_spec.csv', "\xEF\xBB\xBFid,name\n1,a\n".b)
        'csv_file1_spec.csv'
      end

      it 'matches on the first column' do
        expect(compare_results.map { |action, record| [action, record['id']] }).to eq([[:create, '1'], [:delete, '2']])
      end
    end
  end

  context 'when the secondary file is missing' do
    let(:csv_file2) { 'csv_file2_spec_missing.csv' }

    it 'raises without leaving the primary file open' do
      expect { compare_results }.to raise_error(Errno::ENOENT)
      expect(ObjectSpace.each_object(File).none? { |f| !f.closed? && f.path == primary_data_file }).to eq(true)
    end
  end

  context 'with csv options' do
    let(:compare_proc) { proc { |src, dest| src['id'].to_i <=> dest['id'].to_i } }
    let(:csv_compare) { CSVUtils::CSVCompare.new(primary_data_file, ['name'], csv_options, &compare_proc) }

    describe 'tab separated files' do
      let(:csv_options) { { col_sep: "\t" } }
      let(:csv_file1) { File.write('csv_file1_spec.csv', "id\tname\n1\ta\n2\tb\n") && 'csv_file1_spec.csv' }
      let(:csv_file2) { File.write('csv_file2_spec.csv', "id\tname\n1\tchanged\n3\tc\n") && 'csv_file2_spec.csv' }

      it 'reads both files with them' do
        expect(compare_results).to eq(
          [
            [:update, { 'id' => '1', 'name' => 'a' }],
            [:create, { 'id' => '2', 'name' => 'b' }],
            [:delete, { 'id' => '3', 'name' => 'c' }]
          ]
        )
      end
    end

    describe 'binary encoding' do
      let(:csv_options) { { encoding: 'BINARY' } }
      let(:csv_file1) { File.binwrite('csv_file1_spec.csv', "\xEF\xBB\xBFid,name\n1,caf\xE9\n".b) && 'csv_file1_spec.csv' }
      let(:csv_file2) { File.binwrite('csv_file2_spec.csv', "id,name\n1,cafe\n".b) && 'csv_file2_spec.csv' }

      it 'compares bytes that are not valid utf-8 and strips the byte order mark' do
        expect(compare_results).to eq([[:update, { 'id' => '1', 'name' => "caf\xE9".b }]])
      end
    end
  end
end
