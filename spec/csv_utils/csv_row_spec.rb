# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVRow do
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

  context 'csv_headers' do
    subject { test_csv_row.csv_headers }

    it { is_expected.to eq(%w[ID name count]) }
  end

  context 'csv_row' do
    subject { test_csv_row.csv_row }

    it { is_expected.to eq([test_id, name, count]) }
  end
end
