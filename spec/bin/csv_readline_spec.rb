# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-readline' do
  include BinHelper

  it 'prints the columns of a line and flags stray quotes' do
    write_file('data.csv', "\xEF\xBB\xBFid,name,city\n1,\"a\"b,c\n".b)
    out, err, status = run_script('csv-readline', 'data.csv', '2')
    expect(err).to eq('')
    expect(status).to be_success
    expect(out).to eq("  1   id: 1\n* 2   (stray quote) name: \"a\"b\n  3   city: c\n")
  end

  it 'hides empty columns unless --all is given' do
    write_file('data.csv', "id,name,city\n1,,c\n")
    expect(run_script('csv-readline', 'data.csv', '2').first).not_to include('name')
    expect(run_script('csv-readline', '--all', 'data.csv', '2').first).to include('  2   name: ')
  end
end
