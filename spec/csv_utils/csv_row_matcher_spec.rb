# frozen_string_literal: true

require 'spec_helper'

describe CSVUtils::CSVRowMatcher do
  let(:regex) { /test/i }
  let(:columns) { :all }
  let(:matcher) { described_class.new(regex, columns) }

  describe '#initialize' do
    it 'sets the regex' do
      expect(matcher.regex).to eq(regex)
    end

    it 'sets columns to :all by default' do
      matcher = described_class.new(regex)
      expect(matcher.columns).to eq(:all)
    end

    it 'sets specified columns' do
      matcher = described_class.new(regex, %w[name email])
      expect(matcher.columns).to eq(%w[name email])
    end
  end

  describe '#match?' do
    context 'when columns is :all' do
      let(:columns) { :all }

      it 'returns true when any column value matches the regex' do
        row = { 'id' => '123', 'name' => 'Test User', 'email' => 'user@example.com' }
        expect(matcher.match?(row)).to be true
      end

      it 'returns false when no column value matches the regex' do
        row = { 'id' => '123', 'name' => 'John Doe', 'email' => 'user@example.com' }
        expect(matcher.match?(row)).to be false
      end

      it 'handles nil values gracefully' do
        row = { 'id' => nil, 'name' => nil, 'email' => 'testing@example.com' }
        expect(matcher.match?(row)).to be true
      end

      it 'returns false when all values are nil' do
        row = { 'id' => nil, 'name' => nil, 'email' => nil }
        expect(matcher.match?(row)).to be false
      end
    end

    context 'when specific columns are specified' do
      let(:columns) { %w[name email] }

      it 'returns true when a specified column matches' do
        row = { 'id' => 'testing', 'name' => 'Test User', 'email' => 'user@example.com' }
        expect(matcher.match?(row)).to be true
      end

      it 'returns false when only non-specified columns match' do
        row = { 'id' => 'testing', 'name' => 'John Doe', 'email' => 'user@example.com' }
        expect(matcher.match?(row)).to be false
      end

      it 'handles nil values in specified columns' do
        row = { 'id' => '123', 'name' => nil, 'email' => 'test@example.com' }
        expect(matcher.match?(row)).to be true
      end

      it 'handles missing columns gracefully' do
        row = { 'id' => '123' }
        expect(matcher.match?(row)).to be false
      end
    end

    context 'with different regex patterns' do
      it 'matches case-insensitive patterns' do
        matcher = described_class.new(/TEST/i)
        row = { 'name' => 'test value' }
        expect(matcher.match?(row)).to be true
      end

      it 'matches case-sensitive patterns' do
        matcher = described_class.new(/TEST/)
        row = { 'name' => 'test value' }
        expect(matcher.match?(row)).to be false
      end

      it 'matches partial strings' do
        matcher = described_class.new(/user/)
        row = { 'email' => 'testuser@example.com' }
        expect(matcher.match?(row)).to be true
      end

      it 'matches with anchors' do
        matcher = described_class.new(/^test/)
        row = { 'name' => 'testing' }
        expect(matcher.match?(row)).to be true
      end
    end
  end

  describe '#to_proc' do
    let(:rows) do
      [
        { 'id' => '1', 'name' => 'Test User' },
        { 'id' => '2', 'name' => 'John Doe' },
        { 'id' => '3', 'name' => 'Another Test' }
      ]
    end

    it 'returns a proc that can be used with select' do
      matching_rows = rows.select(&matcher)
      expect(matching_rows.length).to eq(2)
      expect(matching_rows.map { |r| r['id'] }).to eq(%w[1 3])
    end

    it 'returns a proc that can be used with reject' do
      non_matching_rows = rows.reject(&matcher)
      expect(non_matching_rows.length).to eq(1)
      expect(non_matching_rows.first['name']).to eq('John Doe')
    end

    it 'returns a proc that can be used with find' do
      first_match = rows.find(&matcher)
      expect(first_match['id']).to eq('1')
    end
  end
end
