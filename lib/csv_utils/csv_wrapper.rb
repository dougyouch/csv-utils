# frozen_string_literal: true

module CSVUtils
  # Wraps a path or an open CSV so callers can read, write and close it the same way.
  # It closes only the files it opened itself.
  class CSVWrapper
    # @return [CSV, #shift, #<<] the CSV being wrapped
    attr_reader :csv

    # @param csv [String, CSV, #shift, #<<] path to open, or a CSV (or array of rows) to use as is
    # @param mode [String] file mode for a path
    # @param csv_options [Hash] options passed to CSV.open for a path
    def initialize(csv, mode, csv_options)
      open(csv, mode, csv_options)
    end

    # Wraps a path or CSV; with a block, yields the wrapper and closes it afterwards, even when the block raises.
    # @param file [String, CSV] path or CSV
    # @param mode [String] file mode for a path
    # @param csv_options [Hash] options passed to CSV.open for a path
    # @yieldparam csv [CSVWrapper]
    # @return [CSVWrapper, Object] the wrapper, or the block's value
    def self.open(file, mode, csv_options = {})
      csv = new(file, mode, csv_options)
      return csv unless block_given?

      begin
        yield csv
      ensure
        csv.close
      end
    end

    # @api private
    # @return [CSV, #shift, #<<]
    def open(csv, mode, csv_options)
      if csv.is_a?(String)
        @close_when_done = true
        @csv = CSV.open(csv, mode, **csv_options)
      else
        @close_when_done = false
        @csv = csv
      end
    end

    # @param row [Array]
    # @return [CSV, #<<]
    def <<(row)
      csv << row
    end

    # @return [Array<String>, nil] the next row, nil at the end
    def shift
      csv.shift
    end

    # @return [String, nil] the raw text of the last row read, with its row separator
    def line
      csv.line
    end

    # @return [String] the row separator, detected from the file when it was :auto
    def row_sep
      csv.row_sep
    end

    # Moves back to the first row.
    # @return [void]
    def rewind
      csv.rewind
    end

    # Closes the CSV if the wrapper opened it.
    # @return [void]
    def close
      csv.close if close_when_done?
    end

    private

    def close_when_done?
      @close_when_done
    end
  end
end
