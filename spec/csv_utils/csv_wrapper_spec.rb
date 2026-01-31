# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVWrapper do
  let(:test_file) { 'csv_wrapper_test.csv' }
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

  describe '#initialize' do
    context 'with a file path' do
      subject { described_class.new(test_file, 'rb', {}) }

      it 'opens the file and provides a CSV object' do
        expect(subject.csv).to be_a(CSV)
      end

      it 'sets close_when_done to true' do
        expect(subject.send(:close_when_done?)).to be true
      end
    end

    context 'with an existing CSV object' do
      let(:csv_object) { CSV.open(test_file, 'rb') }
      subject { described_class.new(csv_object, 'rb', {}) }

      after { csv_object.close }

      it 'uses the provided CSV object' do
        expect(subject.csv).to eq(csv_object)
      end

      it 'sets close_when_done to false' do
        expect(subject.send(:close_when_done?)).to be false
      end
    end
  end

  describe '.open' do
    context 'with a block' do
      it 'yields the wrapper and closes it afterwards' do
        wrapper_instance = nil
        described_class.open(test_file, 'rb') do |wrapper|
          wrapper_instance = wrapper
          expect(wrapper.shift).to eq(headers)
        end
        expect(wrapper_instance.csv.closed?).to be true
      end
    end

    context 'without a block' do
      subject { described_class.open(test_file, 'rb') }

      it 'returns the wrapper without closing' do
        expect(subject).to be_a(described_class)
        expect(subject.csv.closed?).to be false
        subject.close
      end
    end
  end

  describe '#shift' do
    subject { described_class.new(test_file, 'rb', {}) }

    it 'reads rows sequentially' do
      expect(subject.shift).to eq(headers)
      expect(subject.shift).to eq(rows[0])
      expect(subject.shift).to eq(rows[1])
      expect(subject.shift).to eq(rows[2])
      expect(subject.shift).to be_nil
    end
  end

  describe '#rewind' do
    subject { described_class.new(test_file, 'rb', {}) }

    it 'resets reading position to the beginning' do
      subject.shift
      subject.shift
      subject.rewind
      expect(subject.shift).to eq(headers)
    end
  end

  describe '#<<' do
    let(:write_file) { 'csv_wrapper_write_test.csv' }
    subject { described_class.new(write_file, 'wb', {}) }

    after do
      subject.close
      FileUtils.rm_f(write_file)
    end

    it 'writes rows to the CSV' do
      subject << headers
      subject << rows[0]
      subject.close

      expect(CSV.read(write_file)).to eq([headers, rows[0]])
    end
  end

  describe '#close' do
    context 'when opened from file path' do
      subject { described_class.new(test_file, 'rb', {}) }

      it 'closes the underlying CSV' do
        subject.close
        expect(subject.csv.closed?).to be true
      end
    end

    context 'when initialized with existing CSV object' do
      let(:csv_object) { CSV.open(test_file, 'rb') }
      subject { described_class.new(csv_object, 'rb', {}) }

      after { csv_object.close unless csv_object.closed? }

      it 'does not close the underlying CSV' do
        subject.close
        expect(csv_object.closed?).to be false
      end
    end
  end

  describe 'with csv_options' do
    let(:pipe_file) { 'csv_wrapper_pipe_test.csv' }
    let(:pipe_headers) { %w[id name] }
    let(:pipe_rows) { [%w[1 test]] }

    before do
      File.write(pipe_file, "id|name\n1|test\n")
    end

    after do
      FileUtils.rm_f(pipe_file)
    end

    it 'respects csv_options like col_sep' do
      wrapper = described_class.new(pipe_file, 'rb', { col_sep: '|' })
      expect(wrapper.shift).to eq(pipe_headers)
      expect(wrapper.shift).to eq(pipe_rows[0])
      wrapper.close
    end
  end
end
