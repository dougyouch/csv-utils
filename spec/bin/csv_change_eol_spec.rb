# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-change-eol' do
  include BinHelper

  it 'replaces the line endings and keeps trailing whitespace in values' do
    write_file('data.csv', "id,name\n1,\"a b \"\n2,c  \n")
    out, _err, status = run_script('csv-change-eol', 'data.csv', '7C5E7C0A')
    expect(status).to be_success
    expect(out).to eq("data.escaped-eol.csv\n")
    expect(File.binread(tmp_path('data.escaped-eol.csv'))).to eq("id,name|^|\n1,a b |^|\n2,c  |^|\n")
  end

  it 'passes bytes that are not valid utf-8 through unchanged' do
    write_file('latin1.csv', "id,name\n1,caf\xE9\n".b)
    _out, err, status = run_script('csv-change-eol', 'latin1.csv', '0D0A')
    expect(err).to eq('')
    expect(status).to be_success
    expect(File.binread(tmp_path('latin1.escaped-eol.csv'))).to eq("id,name\r\n1,caf\xE9\r\n".b)
  end

  it 'appends the suffix to files without a csv extension' do
    write_file('data.txt', "id\n1\n")
    out, _err, status = run_script('csv-change-eol', 'data.txt', '0A')
    expect(status).to be_success
    expect(out).to eq("data.txt.escaped-eol\n")
  end

  it 'rejects a sequence that is not hex' do
    write_file('data.csv', "id\n1\n")
    _out, err, status = run_script('csv-change-eol', 'data.csv', 'ZZ')
    expect(status).not_to be_success
    expect(err).to include('not a HEX sequence')
  end
end
