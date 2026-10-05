# frozen_string_literal: true

module CSVUtils
  # Detects the separators, byte order mark, encoding and column count of a CSV file from its first line.
  #
  # @example
  #   options = CSVUtils::CSVOptions.new('data.csv')
  #   CSV.open('data.csv', 'rb', col_sep: options.col_separator) if options.valid?
  class CSVOptions
    # @return [Hash{String => String}] byte order marks, as binary strings, to the encoding they indicate
    BYTE_ORDER_MARKS = ByteOrderMark::ENCODINGS

    # @return [Array<String>] column separators to look for, the first one found in the line wins
    COL_SEPARATORS = [
      "\x02",
      "\t",
      '|',
      ','
    ].freeze

    # @return [Array<String>] row separators to look for, the first one found in the line wins
    ROW_SEPARATORS = [
      "\r\n",
      "\n",
      "\r"
    ].freeze

    # @return [Integer, nil] number of headers, nil without a column separator
    attr_reader :columns
    # @return [String, nil] the byte order mark the file starts with, as a binary string
    attr_reader :byte_order_mark
    # @return [String] 'UTF-8', 'UTF-16' or 'UTF-32', from the byte order mark; 'UTF-8' without one
    attr_reader :encoding
    # @return [String, nil] one of {COL_SEPARATORS}
    attr_reader :col_separator
    # @return [String, nil] one of {ROW_SEPARATORS}
    attr_reader :row_separator

    # @param io [String, IO] path of the file, or an IO positioned at its first line
    def initialize(io)
      line = read_first_line(io)

      @col_separator = auto_detect_col_sep(line)
      @row_separator = auto_detect_row_sep(line)
      @byte_order_mark = get_byte_order_mark(line)
      @encoding = get_character_encoding(@byte_order_mark)
      @columns = get_number_of_columns(line) if @col_separator
    end

    # Whether both separators were found. An empty file, or a single line without a newline, isn't valid.
    # @return [Boolean]
    def valid?
      return false if @col_separator.nil? || @row_separator.nil?

      true
    end

    # @api private
    # @param line [String]
    # @return [String, nil]
    def auto_detect_col_sep(line)
      COL_SEPARATORS.detect { |sep| line.include?(sep) }
    end

    # @api private
    # @param line [String]
    # @return [String, nil]
    def auto_detect_row_sep(line)
      ROW_SEPARATORS.detect { |sep| line.include?(sep) }
    end

    # Parses the header line like a CSV row, so quoted headers can contain the separator,
    # and falls back to a plain split when the line is malformed.
    # @param line [String] the first line of the file
    # @return [Array<String, nil>] headers without the byte order mark or row separator
    def get_headers(line)
      line = strip_byte_order_marks(line)
      CSV.parse_line(line, **header_parse_options) || []
    rescue CSV::MalformedCSVError
      line.chomp(row_separator.to_s).split(col_separator, -1)
    end

    # @api private
    # @param line [String]
    # @return [Integer]
    def get_number_of_columns(line)
      get_headers(line).size
    end

    # @api private
    # @param line [String]
    # @return [String, nil]
    def get_byte_order_mark(line)
      ByteOrderMark.detect(line)
    end

    # @api private
    # @param bom [String, nil]
    # @return [String]
    def get_character_encoding(bom)
      BYTE_ORDER_MARKS[bom] || 'UTF-8'
    end

    # @api private
    # @param header [String]
    # @return [String]
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
