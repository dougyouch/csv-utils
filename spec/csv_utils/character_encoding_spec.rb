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
end
