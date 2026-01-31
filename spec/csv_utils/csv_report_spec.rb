# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVReport do
  let(:test_csv_row_class) do
    Class.new do
      include CSVUtils::CSVRow

      attr_accessor :id,
                    :data

      csv_column :id, header: 'ID'
      csv_column(:name) { data[:name] }
      csv_column :count, proc: proc { data[:count] }

      def initialize(id, data)
        self.id = id
        self.data = data
      end
    end
  end

  let(:name) { 'Tester' }
  let(:count) { 91 }
  let(:test_data) do
    {
      name: name,
      extra: 'no used',
      count: count
    }
  end
  let(:test_id) { SecureRandom.uuid }

  let(:test_csv_row) { test_csv_row_class.new(test_id, test_data) }

  let(:csv) { [] }

  let(:csv_report) { CSVUtils::CSVReport.new(csv) }

  let(:expected_csv_data) do
    [
      %w[ID name count],
      [test_id, name, count]
    ]
  end

  let(:expected_csv_content) do
    CSV.generate do |csv|
      expected_csv_data.each { |row| csv << row }
    end
  end

  context 'generate' do
    subject do
      csv_report.generate do |report|
        report.add_headers(test_csv_row)
        report << test_csv_row
      end
    end

    before { subject }

    it { expect(csv).to eq(expected_csv_data) }
  end

  context 'initialize' do
    let(:csv) { 'csv-utils-test.csv' }
    subject do
      CSVUtils::CSVReport.new(csv, test_csv_row_class) do |report|
        report << test_csv_row
      end
    end
    let(:csv_content) { File.read(csv) }

    before { subject }
    after { FileUtils.rm_f(csv) }

    it { expect(csv_content).to eq(expected_csv_content) }
  end
end
