# frozen_string_literal: true

module CSVUtils
  # Writes a CSV file from arrays or {CSVRow} objects.
  #
  # @example
  #   CSVUtils::CSVReport.new('users.csv', UserCSVRow) do |report|
  #     users.each { |user| report << user }
  #   end
  class CSVReport
    # @return [CSV, #<<] where rows are written
    attr_reader :csv
    # @return [Boolean] whether the report opened the file and closes it after {#generate}
    attr_reader :must_close

    # @param csv [String, CSV, #<<] path to write, opened in 'wb' mode by default, or a CSV to append to
    # @param headers [Array<String>, Class, nil] header row, or a {CSVRow} class to take the headers from
    # @param csv_options [Hash] options passed to CSV.open for a path; :mode overrides the file mode and
    #   :encoding, UTF-8 by default, is the encoding of the file written
    # @yieldparam report [CSVReport] when given, the block is passed to {#generate}
    def initialize(csv, headers = nil, csv_options = {}, &block)
      @csv =
        if csv.is_a?(String)
          @must_close = true
          opts = EncodingOptions.write(csv_options)
          mode = opts.delete(:mode) || 'wb'
          CSV.open(csv, mode, **opts)
        else
          @must_close = false
          csv
        end

      add_headers(headers) if headers

      generate(&block) if block
    end

    # Yields the report, then closes the file if the report opened it, even when the block raises.
    # @yieldparam report [CSVReport]
    # @return [void]
    def generate
      yield self
    ensure
      close if @must_close
    end

    # Writes a row.
    # @param csv_row [Array, #to_a] an array of values or a {CSVRow} object
    # @return [CSV, #<<]
    def append(csv_row)
      @csv <<
        if csv_row.is_a?(Array)
          csv_row
        else
          csv_row.to_a
        end
    end
    alias << append

    # Writes the header row.
    # @param csv_row [Array<String>, #csv_headers] headers, or a {CSVRow} class or object to take them from
    # @return [CSV, #<<]
    def add_headers(csv_row)
      append(csv_row.is_a?(Array) ? csv_row : csv_row.csv_headers)
    end

    # Closes the underlying CSV.
    # @return [void]
    def close
      @csv.close
    end
  end
end
