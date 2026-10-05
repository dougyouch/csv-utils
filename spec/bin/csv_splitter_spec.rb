# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-splitter' do
  include BinHelper

  it 'splits a file into parts that each keep the header' do
    write_file('data.csv', "id|name\n1|a\n2|b\n3|c\n")
    _out, err, status = run_script('csv-splitter', '-r', '2', 'data.csv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(File.read(tmp_path('data.part-1-of-2.csv'))).to eq("id|name\n1|a\n2|b\n")
    expect(File.read(tmp_path('data.part-2-of-2.csv'))).to eq("id|name\n3|c\n")
  end

  it 'splits a single column file' do
    write_file('ids.csv', "1\n2\n3\n")
    _out, err, status = run_script('csv-splitter', '--no-header', '-r', '2', 'ids.csv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(File.read(tmp_path('ids.part-1-of-2.csv'))).to eq("1\n2\n")
    expect(File.read(tmp_path('ids.part-2-of-2.csv'))).to eq("3\n")
  end

  it 'names parts of files without a csv extension by number' do
    write_file('data.txt', "id\n1\n2\n")
    _out, _err, status = run_script('csv-splitter', '-r', '1', 'data.txt')
    expect(status).to be_success
    expect(File.read(tmp_path('data.txt.part-2'))).to eq("id\n2\n")
  end

  it 'rejects a row count that is not positive' do
    write_file('data.csv', "id\n1\n")
    _out, err, status = run_script('csv-splitter', '-r', '0', 'data.csv')
    expect(status).not_to be_success
    expect(err).to include('--rows must be positive')
  end
end
