# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-duplicate-finder' do
  include BinHelper

  let(:duplicates) { CSV.read(tmp_path('duplicates-data.csv'), encoding: 'BINARY') }

  it 'reports duplicate rows with their line numbers, ignoring the given headers' do
    write_file('data.csv', "id,name\n1,a\n2,b\n3,a\n")
    _out, err, status = run_script('csv-duplicate-finder', '-i', 'id', 'data.csv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(duplicates.first).to eq(%w[duplicate_key line_no id name])
    expect(duplicates.drop(1).map { |row| row.drop(1) }).to eq([%w[2 1 a], %w[4 3 a]])
    expect(duplicates[1][0]).to eq(duplicates[2][0])
  end

  it 'handles values that are not valid utf-8' do
    write_file('data.csv', "id,name\n1,caf\xE9\n2,caf\xE9\n".b)
    _out, err, status = run_script('csv-duplicate-finder', '-i', 'id', 'data.csv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(duplicates.drop(1).map { |row| row.drop(1) }).to eq([['2', '1', "caf\xE9".b], ['3', '2', "caf\xE9".b]])
  end

  it 'tells empty cells apart from empty strings' do
    write_file('data.csv', "id,name\n1,\n2,\"\"\n")
    _out, _err, status = run_script('csv-duplicate-finder', '-i', 'id', 'data.csv')
    expect(status).to be_success
    expect(duplicates.size).to eq(1)
  end

  it 'rejects unknown ignore headers' do
    write_file('data.csv', "id,name\n1,a\n")
    _out, err, status = run_script('csv-duplicate-finder', '-i', 'missing', 'data.csv')
    expect(status).not_to be_success
    expect(err).to include('unknown headers missing')
  end
end
