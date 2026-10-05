# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::ByteOrderMark do
  {
    'UTF-8' => "\xEF\xBB\xBF",
    'UTF-16 BE' => "\xFE\xFF",
    'UTF-16 LE' => "\xFF\xFE",
    'UTF-32 BE' => "\x00\x00\xFE\xFF",
    'UTF-32 LE' => "\xFF\xFE\x00\x00"
  }.each do |name, bytes|
    context "with a #{name} byte order mark" do
      let(:bom) { bytes.b }
      let(:line) { "#{bom}id,name\n".b }

      it { expect(described_class.detect(line)).to eq(bom) }
      it { expect(described_class.strip(line)).to eq("id,name\n") }
      it { expect(described_class::ENCODINGS[described_class.detect(line)]).to eq(name.split.first) }
    end
  end

  it 'returns nil and the string unchanged without a byte order mark' do
    expect(described_class.detect('id,name')).to be_nil
    expect(described_class.strip('id,name')).to eq('id,name')
  end

  it 'handles utf-8 strings with non-ascii characters' do
    expect(described_class.detect('été,name')).to be_nil
    expect(described_class.strip('﻿été')).to eq('été')
    expect(described_class.strip('﻿été').encoding).to eq(Encoding::UTF_8)
  end

  it 'handles strings shorter than the longest mark' do
    expect(described_class.detect('a')).to be_nil
    expect(described_class.detect('')).to be_nil
  end
end
