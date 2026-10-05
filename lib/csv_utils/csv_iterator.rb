# frozen_string_literal: true

module CSVUtils
  # Enumerates the rows of a CSV file as hashes keyed by header, with the line number of each row.
  #
  # @example
  #   iterator = CSVUtils::CSVIterator.new('data.csv')
  #   iterator.each { |row| puts "#{row.lineno}: #{row['name']}" }
  #   iterator.select { |row| row['status'] == 'active' }
  class CSVIterator
    include Enumerable

    # @return [Array<String>] the byte order marks stripped from the first header, as binary strings
    BYTE_ORDER_MARKS = ByteOrderMark::ENCODINGS.keys.freeze

    # @return [Array<String>, nil] the raw row read before the current one, for debugging malformed rows
    attr_reader :prev_row

    # A row as a hash of header to value that knows its line number in the file.
    class RowWrapper < Hash
      # @return [Integer] line number of the row in the file, counting the header row as line 1
      attr_accessor :lineno

      # @param headers [Array<String>]
      # @param row [Array<String>]
      # @param lineno [Integer]
      # @return [RowWrapper]
      def self.create(headers, row, lineno)
        row_wrapper = RowWrapper[headers.zip(row)]
        row_wrapper.lineno = lineno
        row_wrapper
      end

      # Numbered "header: value" lines for the non-blank values, as csv-grep prints them.
      # @return [String]
      def to_pretty_s
        reject { |_, v| v.nil? || v.strip.empty? }
          .each_with_index
          .map { |(k, v), idx| format('  %-3d %s: %s', idx + 1, k, v) }
          .join("\n") + "\n"
      end
    end

    # @param src_csv [String, CSV] path or CSV to read; it must support rewind
    # @param csv_options [Hash] options passed to CSV.open for a path
    # @param mode [String] file mode for a path; 'rb:BINARY' reads bytes as is
    def initialize(src_csv, csv_options = {}, mode = 'rb')
      @src_csv = CSVUtils::CSVWrapper.new(src_csv, mode, csv_options)
    end

    # Yields each row from the start of the file.
    # @param headers [Array<String>, nil] headers to use; by default the first row is read as the headers
    # @yieldparam row [RowWrapper]
    # @return [Enumerator, nil] an enumerator without a block
    def each(headers = nil)
      return enum_for(:each, headers) unless block_given?

      @src_csv.rewind

      lineno = 0
      unless headers
        headers = read_headers
        lineno += 1
      end

      @prev_row = nil
      while (row = @src_csv.shift)
        lineno += 1
        yield RowWrapper.create(headers, row, lineno)
        @prev_row = row
      end
    end

    # The first row, without the byte order mark.
    # @return [Array<String>] empty for an empty file
    def headers
      @src_csv.rewind
      read_headers
    end

    # Builds a lookup hash from every row.
    # @param key [String] header whose value is the hash key
    # @param value [String, nil] header whose value is the hash value
    # @yieldparam row [RowWrapper] used instead of value to compute the hash value
    # @return [Hash]
    # @raise [RuntimeError] when key or value isn't a header
    def to_hash(key, value = nil, &)
      raise("header #{key} not found in #{headers}") unless headers.include?(key)
      raise("headers #{value} not found in #{headers}") if value && !headers.include?(value)

      value_proc =
        if value
          proc { |row| row[value] }
        else
          proc(&)
        end

      to_h do |row|
        [row[key], value_proc.call(row)]
      end
    end

    # Number of rows after the header row.
    # @return [Integer]
    def size
      @src_csv.rewind
      @src_csv.shift
      cnt = 0
      cnt += 1 while @src_csv.shift
      cnt
    end

    # Yields the rows in batches.
    # @param batch_size [Integer] rows per batch; the last batch may be smaller
    # @yieldparam batch [Array<RowWrapper>]
    # @return [nil]
    def each_batch(batch_size = 1_000)
      batch = []

      process_batch_proc = proc do
        yield batch
        batch = []
      end

      each do |row|
        batch << row
        process_batch_proc.call if batch.size >= batch_size
      end

      process_batch_proc.call if batch.size.positive?

      nil
    end

    private

    # an empty file has no headers, and an empty first header cell is nil
    def read_headers
      headers = @src_csv.shift || []
      headers[0] = ByteOrderMark.strip(headers[0]) if headers[0]
      headers
    end
  end
end
