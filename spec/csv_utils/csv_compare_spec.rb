require 'spec_helper'

describe CSVUtils::CSVCompare do
  let(:csv_file1) do
    csv_file = 'csv_file1_spec.csv'
    CSV.open(csv_file, 'wb') do |csv|
      csv << ['id', 'name', 'date']
      csv << [8, 'test1', '2018-01-09']
      csv << [2, 'test2', '2019-10-12']
      csv << [5, 'test5', '2016-07-21']
      csv << [7, 'test7', '2020-04-13']
    end
    sorted_csv_file = 'csv_file1_spec.sorted.csv'
    csv_sort = CSVUtils::CSVSort.new(csv_file, sorted_csv_file)
    csv_sort.sort { |a, b| a[0] <=> b[0] }
    File.unlink(csv_file)
    sorted_csv_file
  end

  let(:csv_file2) do
    csv_file = 'csv_file2_spec.csv'
    CSV.open(csv_file, 'wb') do |csv|
      csv << ['ID', 'NameType', 'Valid', 'date']
      csv << [8, 'test1', 'Y', '2018-01-09']
      csv << [5, 'test5', 'Y', '2016-07-21']
      csv << [10, 'test10', 'N', '2014-02-05']
      csv << [7, 'test7', 'Y', '2019-12-30']
    end
    sorted_csv_file = 'csv_file2_spec.sorted.csv'
    csv_sort = CSVUtils::CSVSort.new(csv_file, sorted_csv_file)
    csv_sort.sort { |a, b| a[0] <=> b[0] }
    File.unlink(csv_file)
    sorted_csv_file
  end

  let(:primary_data_file) { csv_file1 }
  let(:secondary_data_file) { csv_file2 }
  let(:update_comparison_columns) { ['date'] }
  let(:csv_compare) { CSVUtils::CSVCompare.new(primary_data_file, update_comparison_columns) { |src, dest| src['id'] <=> dest['ID'] } }
  let(:compare_results) do
    results = []
    csv_compare.compare(secondary_data_file) do |action, record|
      results << [action, record]
    end
    results
  end

  after do
    File.unlink(csv_file1)
    File.unlink(csv_file2)
  end

  context 'compare' do
    let(:expected_compare_results) do
      [
        [:delete, {"ID"=>"10", "NameType"=>"test10", "Valid"=>"N", "date"=>"2014-02-05"}],
        [:create, {"date"=>"2019-10-12", "id"=>"2", "name"=>"test2"}],
        [:update, {"date"=>"2020-04-13", "id"=>"7", "name"=>"test7"}]
      ]
    end

    it { expect(compare_results).to eq(expected_compare_results) }
  end
end
