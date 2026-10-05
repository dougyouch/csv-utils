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

    # A row as a hash of header to value that knows its line number in the file.
    class RowWrapper < Hash
      # @return [Integer] line the row starts on in the file, counting the header row as line 1. A quoted value
      #   with a line break spans several lines, so this can differ from the row's position in the file.
      attr_accessor :lineno

      # @param headers [Array<String>]
      # @param row [Array<String>]
      # @param lineno [Integer]
      # @return [RowWrapper]
      def self.create(headers, row, lineno)
        row_wrapper = new
        row_wrapper.lineno = lineno
        # an index loop instead of headers.zip(row), which allocates an array per column for every row
        idx = 0
        size = headers.size
        while idx < size
          row_wrapper[headers[idx]] = row[idx]
          idx += 1
        end
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

    # An iterator for a path, with the separators and encoding detected by {CSVOptions}.
    # @example
    #   CSVUtils::CSVIterator.auto_detect('export.tsv').each { |row| puts row['name'] }
    # @param path [String]
    # @param full_scan [Boolean] check the encoding of the whole file, not only its first megabyte
    # @return [CSVIterator]
    def self.auto_detect(path, full_scan: false)
      options = CSVOptions.new(path, full_scan: full_scan)
      new(path, options.to_csv_options)
    end

    # A path is opened by each method call and closed when the call returns,
    # so an idle iterator holds no file handle.
    # @param src_csv [String, CSV] path or CSV to read; a CSV must support rewind and is never closed
    # @param csv_options [Hash] options passed to CSV.open for a path. The :encoding defaults to 'bom|utf-8'
    #   (see {EncodingOptions}); 'BINARY' reads bytes as is and 'Windows-1252:UTF-8' converts.
    def initialize(src_csv, csv_options = {})
      @src_csv = src_csv
      @csv_options = EncodingOptions.read(csv_options)
    end

    # The raw row read before the current one (the header row for the first row), for debugging;
    # after a full pass it's the last row.
    # @return [Array<String>, nil]
    def prev_row
      @reader&.prev_row
    end

    # Yields each row from the start of the file.
    # @param headers [Array<String>, nil] headers to use; by default the first row is read as the headers
    # @yieldparam row [RowWrapper]
    # @return [Enumerator, nil] an enumerator without a block
    # @raise [MalformedRowError] for a row CSV can't parse, with the line it starts on and {#prev_row}
    # @raise [CSV::InvalidEncodingError] for bytes that don't match the encoding, with their line
    def each(headers = nil, &)
      return enum_for(:each, headers) unless block_given?

      open_csv { |csv| each_row(csv, headers, &) }
    end

    # The first row, without the byte order mark.
    # @return [Array<String>] empty for an empty file
    def headers
      open_csv { |csv| read_headers(csv) }
    end

    # Builds a lookup hash from every row.
    # @param key [String] header whose value is the hash key
    # @param value [String, nil] header whose value is the hash value
    # @yieldparam row [RowWrapper] used instead of value to compute the hash value
    # @return [Hash]
    # @raise [HeaderNotFoundError] when key or value isn't a header
    def to_hash(key, value = nil, &)
      file_headers = headers
      raise HeaderNotFoundError.new(key, file_headers) unless file_headers.include?(key)
      raise HeaderNotFoundError.new(value, file_headers) if value && !file_headers.include?(value)

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
      open_csv do |csv|
        csv.shift
        cnt = 0
        cnt += 1 while csv.shift
        cnt
      end
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

    # Opens a path for the duration of the block. Only a CSV that was passed in is rewound:
    # rewinding goes back to byte 0, in front of a byte order mark the 'bom|' encoding skipped on open.
    def open_csv
      CSVWrapper.open(@src_csv, 'rb', @csv_options) do |csv|
        csv.rewind unless @src_csv.is_a?(String)
        yield csv
      end
    end

    def each_row(csv, headers)
      @reader = RowReader.new(csv)
      headers ||= @reader.shift || []
      while (row = @reader.shift)
        yield RowWrapper.create(headers, row, @reader.lineno)
      end
    end

    # an empty file has no headers, and an empty first header cell is nil
    def read_headers(csv)
      RowReader.new(csv).shift || []
    end
  end
end
