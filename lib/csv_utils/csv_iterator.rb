# frozen_string_literal: true

# Search a CSV given a series of steps
module CSVUtils
  class CSVIterator
    include Enumerable

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
        headers = @src_csv.shift
        strip_bom!(headers[0])
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
      headers = @src_csv.shift
      strip_bom!(headers[0])
      headers
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

      each_with_object({}) do |row, hsh|
        hsh[row[key]] = value_proc.call(row)
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

    def strip_bom!(col)
      col.sub!((+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT'), '')
    end
  end
end
