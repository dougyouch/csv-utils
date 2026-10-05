# frozen_string_literal: true

# Auto detect a csv files options
module CSVUtils
  class CSVOptions
    BYTE_ORDER_MARKS = ByteOrderMark::ENCODINGS

    COL_SEPARATORS = [
      "\x02",
      "\t",
      '|',
      ','
    ].freeze

    ROW_SEPARATORS = [
      "\r\n",
      "\n",
      "\r"
    ].freeze

    attr_reader :columns,
                :byte_order_mark,
                :encoding,
                :col_separator,
                :row_separator

    def initialize(io)
      line = read_first_line(io)

      @col_separator = auto_detect_col_sep(line)
      @row_separator = auto_detect_row_sep(line)
      @byte_order_mark = get_byte_order_mark(line)
      @encoding = get_character_encoding(@byte_order_mark)
      @columns = get_number_of_columns(line) if @col_separator
    end

    def valid?
      return false if @col_separator.nil? || @row_separator.nil?

      true
    end

    def auto_detect_col_sep(line)
      COL_SEPARATORS.detect { |sep| line.include?(sep) }
    end

    def auto_detect_row_sep(line)
      ROW_SEPARATORS.detect { |sep| line.include?(sep) }
    end

    # parses quoted headers like a CSV row, and falls back to a plain split when the line is malformed
    def get_headers(line)
      line = strip_byte_order_marks(line)
      CSV.parse_line(line, **header_parse_options) || []
    rescue CSV::MalformedCSVError
      line.chomp(row_separator.to_s).split(col_separator, -1)
    end

    def get_number_of_columns(line)
      get_headers(line).size
    end

    def get_byte_order_mark(line)
      ByteOrderMark.detect(line)
    end

    def get_character_encoding(bom)
      BYTE_ORDER_MARKS[bom] || 'UTF-8'
    end

    def strip_byte_order_marks(header)
      ByteOrderMark.strip(header)
    end

    private

    # an empty file reads as an empty line, which makes the options invalid
    def read_first_line(io)
      line = io.is_a?(String) ? File.open(io, 'rb', &:gets) : io.gets
      line || ''
    end

    def header_parse_options
      options = { col_sep: col_separator }
      options[:row_sep] = row_separator if row_separator
      options
    end
  end
end
