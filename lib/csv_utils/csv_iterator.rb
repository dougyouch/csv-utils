# frozen_string_literal: true

# Search a CSV given a series of steps
module CSVUtils
  class CSVIterator
    include Enumerable

    BYTE_ORDER_MARKS = ByteOrderMark::ENCODINGS.keys.freeze

    attr_reader :prev_row

    class RowWrapper < Hash
      attr_accessor :lineno

      def self.create(headers, row, lineno)
        row_wrapper = RowWrapper[headers.zip(row)]
        row_wrapper.lineno = lineno
        row_wrapper
      end

      def to_pretty_s
        reject { |_, v| v.nil? || v.strip.empty? }
          .each_with_index
          .map { |(k, v), idx| format('  %-3d %s: %s', idx + 1, k, v) }
          .join("\n") + "\n"
      end
    end

    def initialize(src_csv, csv_options = {}, mode = 'rb')
      @src_csv = CSVUtils::CSVWrapper.new(src_csv, mode, csv_options)
    end

    def each(headers = nil)
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

    def headers
      @src_csv.rewind
      read_headers
    end

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

    def size
      @src_csv.rewind
      @src_csv.shift
      cnt = 0
      cnt += 1 while @src_csv.shift
      cnt
    end

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
