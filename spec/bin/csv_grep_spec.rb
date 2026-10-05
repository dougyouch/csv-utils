# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-grep' do
  include BinHelper

  it 'searches a tab separated file' do
    write_file('data.tsv', "id\tname\n1\talpha\n2\tbeta\n")
    out, err, status = run_script('csv-grep', '-s', 'bet', '-c', 'name', 'data.tsv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(out).to eq("  1   id: 2\n  2   name: beta\n\n")
  end

  it 'searches a Windows-1252 file as UTF-8' do
    write_file('data.csv', "id,name\n1,caf\xE9\n".b)
    out, err, status = run_script('csv-grep', '-s', "caf\u00E9", '-c', 'name', 'data.csv')
    expect(err).to eq('')
    expect(status).to be_success
    expect(out).to include("name: caf\u00E9")
  end
end
