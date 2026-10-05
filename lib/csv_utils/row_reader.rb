# frozen_string_literal: true

module CSVUtils
  # Reads rows from a CSV positioned at its first line, keeping the physical line each row starts on.
  # CSV counts rows, so a quoted value with a line break would make its line numbers fall behind.
  # The byte order mark is stripped from the first row, and rows CSV can't parse raise {MalformedRowError}.
  #
  # @example
  #   reader = CSVUtils::RowReader.new(csv)
  #   headers = reader.shift
  #   while (row = reader.shift)
  #     puts "#{reader.lineno}: #{row.inspect}"
  #   end
  class RowReader
    # @return [Integer, nil] line the last row read starts on, counting the first line as 1
    attr_reader :lineno
    # @return [Array<String>, nil] the row read before the last one
    attr_reader :prev_row

    # @param csv [CSV, CSVWrapper] positioned at the first line
    def initialize(csv)
      @csv = csv
      @last_line = 0
      @row = nil
      @prev_row = nil
    end

    # @return [Array<String>, nil] the next row, nil at the end
    # @raise [MalformedRowError] for a row CSV can't parse, with the line it starts on
    # @raise [CSV::InvalidEncodingError] for bytes that don't match the encoding; CSV raises it when it buffers
    #   them, ahead of the rows before them, with the right line already
    def shift
      row = @csv.shift
      @lineno = @last_line + 1
      count_lines(row) if row
      @prev_row = @row
      @row = row
    rescue CSV::InvalidEncodingError
      raise
    rescue CSV::MalformedCSVError => e
      raise MalformedRowError.new(e.message.delete_suffix(" in line #{e.line_number}."), @last_line + 1, @row)
    end

    private

    def count_lines(row)
      row[0] = ByteOrderMark.strip(row[0]) if @last_line.zero? && row[0]
      @last_line += @csv.line.count(@csv.row_sep[-1])
    end
  end
end
