# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-diff' do
  include BinHelper

  let(:results) { CSV.read(tmp_path('diff-results-old.csv')) }

  before do
    write_file('old.csv', old_csv)
    write_file('new.csv', new_csv)
  end

  context 'with a unique header other than the first column' do
    let(:old_csv) { "code,id,value\na,2,x\nb,1,y\n" }
    let(:new_csv) { "code,id,value\nz,1,y\nq,2,changed\n" }

    it 'matches rows on that header' do
      _out, err, status = run_script('csv-diff', '-u', 'id', 'old.csv', 'new.csv')
      expect(err).to eq('')
      expect(status).to be_success
      expect(results).to eq([%w[Result code id value], %w[update b 1 y], %w[update a 2 x]])
    end
  end

  context 'with empty cells' do
    let(:old_csv) { "id,name\n1,\n2,b\n" }
    let(:new_csv) { "id,name\n1,a\n2,b\n3,\n" }

    it 'compares them as empty strings' do
      _out, err, status = run_script('csv-diff', 'old.csv', 'new.csv')
      expect(err).to eq('')
      expect(status).to be_success
      expect(results).to eq([%w[Result id name], ['update', '1', nil], ['delete', '3', nil]])
    end
  end

  context 'with ignored headers' do
    let(:old_csv) { "id,name,updated_at\n1,a,2026-01-01\n" }
    let(:new_csv) { "id,name,updated_at\n1,a,2026-02-01\n" }

    it 'reports identical files and removes the sorted copies' do
      out, _err, status = run_script('csv-diff', '-i', 'updated_at', 'old.csv', 'new.csv')
      expect(status).to be_success
      expect(out).to include('files were identical')
      expect(Dir.children(tmp_dir)).to contain_exactly('old.csv', 'new.csv')
    end
  end

  context 'with different headers' do
    let(:old_csv) { "id,name\n1,a\n" }
    let(:new_csv) { "id,title\n1,a\n" }

    it 'exits with an error' do
      _out, err, status = run_script('csv-diff', 'old.csv', 'new.csv')
      expect(status).not_to be_success
      expect(err).to include('headers do not match')
    end
  end

  context 'with one file' do
    let(:old_csv) { "id\n1\n" }
    let(:new_csv) { "id\n1\n" }

    it 'prints the usage' do
      _out, err, status = run_script('csv-diff', 'old.csv')
      expect(status).not_to be_success
      expect(err).to include('<csv file 1> <csv file 2>')
    end
  end

  context 'with tab separated files' do
    let(:old_csv) { "id\tname\n1\ta\n2\tb\n" }
    let(:new_csv) { "id\tname\n2\tc\n1\ta\n" }

    it 'detects the separator' do
      _out, err, status = run_script('csv-diff', 'old.csv', 'new.csv')
      expect(err).to eq('')
      expect(status).to be_success
      expect(results).to eq([%w[Result id name], %w[update 2 b]])
    end
  end

  context 'with different separators' do
    let(:old_csv) { "id\tname\n1\ta\n" }
    let(:new_csv) { "id,name\n1,a\n" }

    it 'exits with an error' do
      _out, err, status = run_script('csv-diff', 'old.csv', 'new.csv')
      expect(status).not_to be_success
      expect(err).to include('column separators do not match')
    end
  end
end
