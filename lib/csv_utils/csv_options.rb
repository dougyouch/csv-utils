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

    # @return [Hash{String => String}] byte order marks, as binary strings, to the file mode that decodes them;
    #   a UTF-8 mark is stripped from the first header, so it needs no special mode
    MODES = {
      (+"\x00\x00\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'rb:BOM|UTF-32BE:UTF-8',
      (+"\xFF\xFE\x00\x00").force_encoding('ASCII-8BIT').freeze => 'rb:BOM|UTF-32LE:UTF-8',
      (+"\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'rb:BOM|UTF-16BE:UTF-8',
      (+"\xFF\xFE").force_encoding('ASCII-8BIT').freeze => 'rb:BOM|UTF-16LE:UTF-8'
    }.freeze

    # @return [Integer] bytes read to detect the encoding of a file without a byte order mark
    SAMPLE_SIZE = 1024 * 1024

    # @return [Integer, nil] number of headers, nil without a column separator
    attr_reader :columns
    # @return [String, nil] the byte order mark the file starts with, as a binary string
    attr_reader :byte_order_mark
    # @return [String] 'UTF-8', 'UTF-16' or 'UTF-32' from the byte order mark; without one, from the bytes of
    #   the first {SAMPLE_SIZE} bytes: 'UTF-8', 'Windows-1252' or 'ISO-8859-1' (see {CharacterEncoding.detect})
    attr_reader :encoding
    # @return [String, nil] one of {COL_SEPARATORS}
    attr_reader :col_separator
    # @return [String, nil] one of {ROW_SEPARATORS}
    attr_reader :row_separator

    # @param io [String, IO] path of the file, or an IO positioned at its first line; up to {SAMPLE_SIZE}
    #   bytes are read from it
    def initialize(io)
      sample = read_sample(io)
      line = first_line(sample)

      @col_separator = auto_detect_col_sep(line)
      @row_separator = auto_detect_row_sep(line)
      @byte_order_mark = get_byte_order_mark(line)
      @encoding = get_character_encoding(@byte_order_mark, sample)
      @columns = get_number_of_columns(line) if @col_separator
    end

    # Whether both separators were found. An empty file, or a single line without a newline, isn't valid.
    # @return [Boolean]
    def valid?
      return false if @col_separator.nil? || @row_separator.nil?

      true
    end

    # Options for CSV.open with the detected separators; a separator that wasn't detected is left to CSV.
    # The row separator is left to CSV for UTF-16 and UTF-32 files too, since it's detected from raw bytes.
    # @example
    #   CSV.open(path, options.mode, **options.to_csv_options)
    # @return [Hash{Symbol => String}]
    def to_csv_options
      options = {}
      options[:col_sep] = col_separator if col_separator
      options[:row_sep] = row_separator if row_separator && !wide_encoding?
      options
    end

    # File mode for CSV.open that reads the file as UTF-8 strings whatever the locale: 'rb:BOM|UTF-8' for UTF-8,
    # or a mode like 'rb:Windows-1252:UTF-8' that converts other encodings.
    # @return [String]
    def mode
      MODES.fetch(byte_order_mark) { encoding == 'UTF-8' ? 'rb:BOM|UTF-8' : "rb:#{encoding}:UTF-8" }
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
    # @param sample [String] bytes from the start of the file
    # @return [String]
    def get_character_encoding(bom, sample)
      BYTE_ORDER_MARKS[bom] || CharacterEncoding.detect(sample)
    end

    # @api private
    # @param header [String]
    # @return [String]
    def strip_byte_order_marks(header)
      ByteOrderMark.strip(header)
    end

    private

    # an empty file reads as an empty sample, which makes the options invalid
    def read_sample(io)
      sample = (io.is_a?(String) ? File.open(io, 'rb') { |file| file.read(SAMPLE_SIZE) } : io.read(SAMPLE_SIZE)) || ''
      sample.bytesize < SAMPLE_SIZE ? sample : drop_last_multibyte_char(sample)
    end

    # a full sample can end mid-character, so its last multibyte character, whole or not, is dropped
    def drop_last_multibyte_char(sample)
      sample.sub(/[\xC0-\xFF][\x80-\xBF]*\z/n, '')
    end

    def first_line(sample)
      line_end = sample.index("\n")
      line_end ? sample.byteslice(0, line_end + 1) : sample
    end

    def wide_encoding?
      MODES.key?(byte_order_mark)
    end

    def header_parse_options
      options = { col_sep: col_separator }
      options[:row_sep] = row_separator if row_separator
      options
    end
  end
end
