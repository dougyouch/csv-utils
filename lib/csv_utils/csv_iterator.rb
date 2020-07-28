# Search a CSV given a series of steps
class CSVUtils::CSVIterator
  include Enumerable

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

    while (row = @src_csv.shift)
      lineno += 1
      yield Hash[headers.zip(row)], lineno
    end
  end

  private

  def strip_bom!(col)
    col.sub!("\xEF\xBB\xBF".force_encoding('ASCII-8BIT'), '')
  end
end
