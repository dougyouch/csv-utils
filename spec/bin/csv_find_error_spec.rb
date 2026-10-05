# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-find-error' do
  include BinHelper

  it 'reports a valid file' do
    write_file('data.csv', "id,name\n1,a\n")
    out, _err, status = run_script('csv-find-error', 'data.csv')
    expect(status).to be_success
    expect(out).to eq("CSV file is ok\n")
  end

  it 'shows the malformed line with the csv-readline next to it' do
    write_file('my data.csv', "id,name\n1,a\n2,\"b\"x\n")
    out, _err, status = run_script('csv-find-error', 'my data.csv')
    expect(status).not_to be_success
    expect(out).to include('CSVUtils::MalformedRowError', 'previous row was ["1", "a"]', 'running csv-readline my data.csv 3')
    expect(out).to include('* 2   (stray quote) name: "b"x')
  end

  it 'reports the physical line after a quoted line break' do
    write_file('data.csv', "id,note\n1,\"two\nlines\"\n2,\"b\"x\n")
    out, _err, status = run_script('csv-find-error', 'data.csv')
    expect(status).not_to be_success
    expect(out).to include('in line 4.', 'running csv-readline data.csv 4', '(stray quote) note: "b"x')
  end

  it 'reports bytes that are not valid UTF-8 without a previous row' do
    write_file('data.csv', "id,note\n1,a\n2,b\xE9\n".b)
    out, _err, status = run_script('csv-find-error', 'data.csv')
    expect(status).to be_success
    expect(out).to eq("CSV file is ok\n")
  end
end
