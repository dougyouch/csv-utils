# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVTransformer do
  let(:src_csv) do
    [
      %w[ID Name],
      %w[319 Foo],
      %w[91 Bar],
      %w[19133158 Unknown]
    ]
  end
  let(:dest_csv) { [] }
  let(:csv_options) { {} }
  let(:csv_transformer) do
    CSVUtils::CSVTransformer.new(
      src_csv,
      dest_csv,
      csv_options
    )
  end

  context 'read_headers' do
    subject { csv_transformer.read_headers }
    let(:src_csv_headers) { csv_transformer.headers }

    before { subject }

    it { expect(src_csv_headers).to eq(%w[ID Name]) }
  end

  context 'select' do
    subject do
      csv_transformer
        .read_headers
        .select { |row, headers, _additional_data| headers.zip(row).to_h['ID'] == '91' }
        .process(2)
    end

    let(:expected_csv) do
      [
        %w[ID Name],
        %w[91 Bar]
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'reject' do
    subject do
      csv_transformer
        .read_headers
        .reject { |row, headers, _additional_data| headers.zip(row).to_h['ID'] == '91' }
        .process(2)
    end

    let(:expected_csv) do
      [
        %w[ID Name],
        %w[319 Foo],
        %w[19133158 Unknown]
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'map' do
    subject do
      csv_transformer
        .read_headers
        .map(['IDx2']) { |row, headers, _additional_data| [(headers.zip(row).to_h['ID'].to_i * 2).to_s] }
        .process(2)
    end

    let(:expected_csv) do
      [
        ['IDx2'],
        ['638'],
        ['182'],
        ['38266316']
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'append with additional_data' do
    subject do
      csv_transformer
        .read_headers
        .additional_data { |rows| rows.to_h { |row| [row[0], "#{row[1].downcase}@example.com"] } }
        .append(['Email']) { |row, _headers, additional_data| [additional_data[row[0]]] }
        .process(2)
    end

    let(:expected_csv) do
      [
        ['ID', 'Name', 'Email'],
        ['319', 'Foo', 'foo@example.com'],
        ['91', 'Bar', 'bar@example.com'],
        ['19133158', 'Unknown', 'unknown@example.com']
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'each' do
    subject do
      csv_transformer
        .read_headers
        .each { |row, _headers, _additional_data| row + [1] }
        .process(2)
    end

    let(:expected_csv) do
      [
        %w[ID Name],
        %w[319 Foo],
        %w[91 Bar],
        %w[19133158 Unknown]
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'set_headers' do
    subject do
      csv_transformer
        .read_headers
        .each { |row, _headers, _additional_data| row + [1] }
        .set_headers(%w[id first_name])
        .process(2)
    end

    let(:expected_csv) do
      [
        %w[id first_name],
        %w[319 Foo],
        %w[91 Bar],
        %w[19133158 Unknown]
      ]
    end

    before { subject }

    it { expect(dest_csv).to eq(expected_csv) }
  end

  context 'append without headers' do
    subject do
      csv_transformer
        .append(['Email']) { |row, _headers, _additional_data| ["#{row[1].downcase}@example.com"] }
        .process
    end

    before { subject }

    it 'appends to every row, including the first, without a header row' do
      expect(dest_csv).to eq(
        [
          %w[ID Name name@example.com],
          %w[319 Foo foo@example.com],
          %w[91 Bar bar@example.com],
          %w[19133158 Unknown unknown@example.com]
        ]
      )
    end
  end

  context 'append with nil headers' do
    subject do
      csv_transformer
        .read_headers
        .append(nil) { |row, _headers, _additional_data| [row[0].size.to_s] }
        .process
    end

    before { subject }

    it 'drops the header row' do
      expect(dest_csv).to eq([%w[319 Foo 3], %w[91 Bar 2], %w[19133158 Unknown 8]])
    end
  end
end
