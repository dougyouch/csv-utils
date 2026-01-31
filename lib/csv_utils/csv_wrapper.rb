# frozen_string_literal: true

# Wraps a CSV object, if wrapper opens the csv file it will close it
module CSVUtils
  class CSVWrapper
    attr_reader :csv

    def initialize(csv, mode, csv_options)
      open(csv, mode, csv_options)
    end

    def self.open(file, mode, csv_options = {})
      csv = new(file, mode, csv_options)

      if block_given?
        yield csv
        csv.close
      else
        csv
      end
    end

    def open(csv, mode, csv_options)
      if csv.is_a?(String)
        @close_when_done = true
        @csv = CSV.open(csv, mode, **csv_options)
      else
        @close_when_done = false
        @csv = csv
      end
    end

    def <<(row)
      csv << row
    end

    def shift
      csv.shift
    end

    def rewind
      csv.rewind
    end

    def close
      csv.close if close_when_done?
    end

    private

    def close_when_done?
      @close_when_done
    end
  end
end
