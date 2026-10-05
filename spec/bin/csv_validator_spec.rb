# frozen_string_literal: true

require 'spec_helper'
require 'support/bin_helper'

describe 'bin/csv-validator' do
  include BinHelper

  # rchardet isn't a dependency, so the spec stands in for it with a fixed answer
  let(:fake_gems) { File.join(tmp_dir, 'fake_gems') }
  let(:detected_encoding) { 'ISO-8859-1' }

  before do
    FileUtils.mkdir_p(fake_gems)
    File.write(File.join(fake_gems, 'rchardet.rb'), <<~RUBY)
      module CharDet
        def self.detect(_str) = { 'encoding' => #{detected_encoding.inspect} }
      end
    RUBY
    write_file('data.csv', "\xEF\xBB\xBFid,name\n1,caf\xE9\n2,ok,extra\n".b)
  end

  def run_validator
    run_script('csv-validator', 'data.csv', load_path: [fake_gems])
  end

  it 'reports values that are not utf-8 and writes the corrections' do
    out, err, status = run_validator
    expect(status).to be_success
    expect(err).to include('row(2),col(2) name: non UTF-8 characters found in "caf\xE9"')
    expect(err).to include('row(3): invalid number of columns, expected 2 got 3')
    expect(out).to include('converted to UTF-8 from ISO-8859-1 "café"')
    expect(CSV.read(tmp_path('utf8-correction.csv'))).to eq([%w[id Row Col Header Value], %w[1 2 2 name café]])
  end

  context 'when the encoding cannot be detected' do
    let(:detected_encoding) { nil }

    it 'reports the value as unknown' do
      _out, err, status = run_validator
      expect(status).to be_success
      expect(err).to include('row(2),col(2) name: unknown character encoding')
      expect(File).not_to exist(tmp_path('utf8-correction.csv'))
    end
  end
end
