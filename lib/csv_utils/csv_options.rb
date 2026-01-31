# frozen_string_literal: true

# Auto detect a csv files options
module CSVUtils
  class CSVOptions
    # this list is from https://en.wikipedia.org/wiki/Byte_order_mark
    BYTE_ORDER_MARKS = {
      (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT') => 'UTF-8',
      (+"\xFE\xFF").force_encoding('ASCII-8BIT') => 'UTF-16',
      (+"\xFF\xFE").force_encoding('ASCII-8BIT') => 'UTF-16',
      (+"\x00\x00\xFE\xFF").force_encoding('ASCII-8BIT') => 'UTF-32',
      (+"\xFF\xFE\x00\x00").force_encoding('ASCII-8BIT') => 'UTF-32'
    }.freeze

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
      BYTE_ORDER_MARKS.keys.detect do |bom|
        line =~ /\A#{bom}/
      end
    end

    def get_character_encoding(bom)
      BYTE_ORDER_MARKS[bom] || 'UTF-8'
    end

    def strip_byte_order_marks(header)
      @byte_order_mark ? header.sub(@byte_order_mark, '') : header
    end
  end
end
