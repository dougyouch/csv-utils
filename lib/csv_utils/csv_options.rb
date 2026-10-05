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
      line =
        if io.is_a?(String)
          File.open(io, 'rb', &:readline)
        else
          io.readline
        end

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

    def get_headers(line)
      headers = line.split(col_separator)
      headers[0] = strip_byte_order_marks(headers[0])
      headers
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
  end
end
