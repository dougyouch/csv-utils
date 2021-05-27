# Search a CSV given a series of steps
class CSVUtils::CSVIterator
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
        .map { |(k, v), idx| sprintf('  %-3d %s: %s', idx+1, k, v) }
        .join("\n") + "\n"
    end
  end

  def initialize(src_csv, csv_options = {})
    @src_csv = CSVUtils::CSVWrapper.new(src_csv, 'rb', csv_options)
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
    first.keys
  end

  def to_hash(key, value = nil)
    raise("header #{key} not found in #{headers}") unless headers.include?(key)
    raise("headers #{value} not found in #{headers}") if value && !headers.include?(value)

    value_proc =
      if value
        proc { |row| row[value] }
      else
        proc { |row| yield(row) }
      end

    each_with_object({}) do |row, hsh|
      hsh[row[key]] = value_proc.call(row)
    end
  end

  private

  def strip_bom!(col)
    col.sub!("\xEF\xBB\xBF".force_encoding('ASCII-8BIT'), '')
  end
end
