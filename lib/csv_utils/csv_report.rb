# Builds a csv file from csv rows
module CSVUtils
  class CSVReport
    attr_reader :csv,
                :must_close

    def initialize(csv, csv_options = {}, &block)
      @csv =
        if csv.is_a?(String)
          @must_close = true
          mode = csv_options.delete(:mode) || 'wb'
          CSV.open(csv, mode, csv_options)
        else
          @must_close = false
          csv
        end

      generate(&block) if block
    end

    def generate
      yield self
      @csv.close if @must_close
    end

    def append(csv_row)
      @csv <<
        if csv_row.is_a?(Array)
          csv_row
        else
          csv_row.to_a
        end
    end
    alias << append

    def add_headers(csv_row)
      append(csv_row.is_a?(Array) ? csv_row : csv_row.csv_headers)
    end
  end
end