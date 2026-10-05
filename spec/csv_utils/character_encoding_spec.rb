# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CharacterEncoding do
  describe '.detect' do
    {
      'an empty sample' => ['', 'UTF-8'],
      'ASCII' => ["id,name\n1,a\n", 'UTF-8'],
      'UTF-8' => ["id,name\n1,caf\u00E9\n", 'UTF-8'],
      'UTF-8 read as binary' => ["id,name\n1,caf\u00E9\n".b, 'UTF-8'],
      'Windows-1252 smart quotes and euro' => ["1,\x93a\x94 \x80\n".b, 'Windows-1252'],
      'Latin-1 accents' => ["1,caf\xE9\n".b, 'Windows-1252'],
      'a byte Windows-1252 leaves undefined' => ["1,caf\xE9\x8D\n".b, 'ISO-8859-1']
    }.each do |name, (sample, encoding)|
      it "detects #{encoding} for #{name}" do
        expect(described_class.detect(sample)).to eq(encoding)
      end
    end

    it "doesn't change the sample's encoding" do
      sample = "caf\xE9".b
      described_class.detect(sample)
      expect(sample.encoding).to eq(Encoding::BINARY)
    end
  end

  describe '.detect with a truncated sample' do
    it 'ignores an incomplete last character' do
      expect(described_class.detect("caf\xC3".b, truncated: true)).to eq('UTF-8')
      expect(described_class.detect("caf\xC3".b)).to eq('Windows-1252')
    end
  end

  describe '.detect_stream' do
    it 'checks a character split between chunks whole' do
      expect(described_class.detect_stream(["caf\xC3".b, "\xA9 \xF0\x9F".b, "\x98\x80\n".b])).to eq('UTF-8')
    end

    it 'finds bytes that are not UTF-8 in a later chunk' do
      expect(described_class.detect_stream(['id,name\n', "1,caf\xE9\n".b])).to eq('Windows-1252')
    end

    it 'keeps looking for undefined Windows-1252 bytes after the first invalid chunk' do
      expect(described_class.detect_stream(["caf\xE9".b, 'abc', "\x8D".b])).to eq('ISO-8859-1')
    end

    it 'reports an incomplete character at the end of the file' do
      expect(described_class.detect_stream(["caf\xC3".b])).to eq('Windows-1252')
    end

    it 'checks continuation bytes without a lead byte' do
      expect(described_class.detect_stream(["abcde\x80\x80\x80\x80\x80".b])).to eq('Windows-1252')
    end
  end
end
