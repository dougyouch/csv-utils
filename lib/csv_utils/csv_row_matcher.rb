# frozen_string_literal: true

module CSVUtils
  # Matches rows (hashes of header to value) whose values match a regular expression.
  #
  # @example
  #   matcher = CSVUtils::CSVRowMatcher.new(/error/i, ['status', 'message'])
  #   CSVUtils::CSVIterator.new('logs.csv').select(&matcher)
  class CSVRowMatcher
    # @return [Regexp]
    attr_accessor :regex
    # @return [Array<String>, :all] headers to search, or :all for every value
    attr_accessor :columns

    # @param regex [Regexp]
    # @param columns [Array<String>, :all] headers to search
    def initialize(regex, columns = :all)
      self.regex = regex
      self.columns = columns
    end

    # Whether any searched value matches. Missing and nil values never match.
    # @param row [Hash{String => String}]
    # @return [Boolean]
    def match?(row)
      if columns == :all
        row.each_value do |value|
          return true if value&.match?(regex)
        end
      else
        columns.each do |column_name|
          value = row[column_name]
          return true if value&.match?(regex)
        end
      end

      false
    end

    # Lets the matcher be passed to Enumerable methods as a block, as in rows.select(&matcher).
    # @return [Proc]
    def to_proc
      proc do |row|
        match?(row)
      end
    end
  end
end
