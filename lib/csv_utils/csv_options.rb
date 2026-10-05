# frozen_string_literal: true

module CSVUtils
  # Detects the separators, byte order mark, encoding and column count of a CSV file from its header row
  # and, for the encoding, its first {SAMPLE_SIZE} bytes or, with full_scan, all of them.
  #
  # @example
  #   options = CSVUtils::CSVOptions.new('data.csv')
  #   CSV.open('data.csv', 'rb', col_sep: options.col_separator) if options.valid?
  class CSVOptions
    # @return [Hash{String => String}] byte order marks, as binary strings, to the encoding they indicate
    BYTE_ORDER_MARKS = ByteOrderMark::ENCODINGS

    # @return [Array<String>] column separators to look for; the one found most often outside quotes in the
    #   header row wins, and on a tie the one listed first
    COL_SEPARATORS = [
      "\x02",
      "\t",
      '|',
      ',',
      ';'
    ].freeze

    # @return [Array<String>] row separators to look for, the first one found in the line wins
    ROW_SEPARATORS = [
      "\r\n",
      "\n",
      "\r"
    ].freeze

    # @return [Hash{String => String}] UTF-16 and UTF-32 byte order marks, as binary strings, to the :encoding
    #   option that decodes them to UTF-8
    WIDE_ENCODINGS = {
      (+"\x00\x00\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'BOM|UTF-32BE:UTF-8',
      (+"\xFF\xFE\x00\x00").force_encoding('ASCII-8BIT').freeze => 'BOM|UTF-32LE:UTF-8',
      (+"\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'BOM|UTF-16BE:UTF-8',
      (+"\xFF\xFE").force_encoding('ASCII-8BIT').freeze => 'BOM|UTF-16LE:UTF-8'
    }.freeze

    # @return [Integer] bytes read to detect the encoding of a file without a byte order mark
    SAMPLE_SIZE = 1024 * 1024

    QUOTED = /"[^"]*"/n
    # the header row: up to the first line break outside quotes
    HEADER_ROW = /\A(?:[^"\r\n]|"[^"]*")*(?:\r\n|\n|\r)?/n
    LINE_BREAK = /\r\n|\n|\r/n
    private_constant :QUOTED, :HEADER_ROW, :LINE_BREAK

    # @return [Integer, nil] number of headers, nil without a column separator
    attr_reader :columns
    # @return [String, nil] the byte order mark the file starts with, as a binary string
    attr_reader :byte_order_mark
    # @return [String] 'UTF-8', 'UTF-16' or 'UTF-32' from the byte order mark; without one, from the first
    #   {SAMPLE_SIZE} bytes, or all of them with full_scan: 'UTF-8', 'Windows-1252' or 'ISO-8859-1'
    #   (see {CharacterEncoding.detect})
    attr_reader :encoding
    # @return [String, nil] one of {COL_SEPARATORS}
    attr_reader :col_separator
    # @return [String, nil] one of {ROW_SEPARATORS}
    attr_reader :row_separator

    # @param io [String, IO] path of the file, or an IO positioned at its first line; up to {SAMPLE_SIZE}
    #   bytes are read from it, or all of it with full_scan
    # @param full_scan [Boolean] check the encoding of the whole file, in {SAMPLE_SIZE} chunks, for files whose
    #   first bytes that aren't UTF-8 may come after the sample
    def initialize(io, full_scan: false)
      open_io(io) do |input|
        sample = input.read(SAMPLE_SIZE) || ''
        line = first_line(sample)

        @col_separator = auto_detect_col_sep(line)
        @row_separator = auto_detect_row_sep(line)
        @byte_order_mark = get_byte_order_mark(line)
        @encoding = get_character_encoding(@byte_order_mark, sample, full_scan ? input : nil)
        @columns = get_number_of_columns(line) if @col_separator
      end
    end

    # Whether both separators were found. An empty file, or a single line without a newline, isn't valid.
    # @return [Boolean]
    def valid?
      return false if @col_separator.nil? || @row_separator.nil?

      true
    end

    # Options for CSV.open, or any class in this library, with the detected separators and an :encoding that
    # reads values as UTF-8 strings: 'bom|utf-8', 'Windows-1252:UTF-8', 'BOM|UTF-16LE:UTF-8' and so on.
    # A separator that wasn't detected is left to CSV, and so is the row separator of UTF-16 and UTF-32 files,
    # since it's detected from raw bytes.
    # @example
    #   CSV.open(path, 'rb', **options.to_csv_options)
    #   CSVUtils::CSVSort.new(path, 'sorted.csv', true, options.to_csv_options).sort
    # @return [Hash{Symbol => String}]
    def to_csv_options
      options = { encoding: encoding_option }
      options[:col_sep] = col_separator if col_separator
      options[:row_sep] = row_separator if row_separator && !wide_encoding?
      options
    end

    # @api private
    # @param line [String] the header row
    # @return [String, nil] the separator found most often outside quotes, nil when there's none
    def auto_detect_col_sep(line)
      unquoted = line.b.gsub(QUOTED, '')
      counts = COL_SEPARATORS.map { |sep| unquoted.count(sep) }
      return if counts.max.zero?

      COL_SEPARATORS[counts.index(counts.max)]
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
    # @param rest [IO, nil] the rest of the file, to scan it all
    # @return [String]
    def get_character_encoding(bom, sample, rest = nil)
      return BYTE_ORDER_MARKS[bom] if bom
      return CharacterEncoding.detect_stream(chunks(sample, rest)) if rest

      CharacterEncoding.detect(sample, truncated: sample.bytesize == SAMPLE_SIZE)
    end

    # @api private
    # @param header [String]
    # @return [String]
    def strip_byte_order_marks(header)
      ByteOrderMark.strip(header)
    end

    private

    # an empty file reads as an empty sample, which makes the options invalid
    def open_io(io, &)
      io.is_a?(String) ? File.open(io, 'rb', &) : yield(io)
    end

    def chunks(sample, rest)
      Enumerator.new do |chunks|
        chunks << sample
        while (chunk = rest.read(SAMPLE_SIZE))
          chunks << chunk
        end
      end
    end

    # The header row, which a quoted line break doesn't end. A stray quote falls back to the first line.
    def first_line(sample)
      line = sample.b[HEADER_ROW]
      return line if line.bytesize == sample.bytesize || line.end_with?("\n", "\r")

      line_break = sample.b.match(LINE_BREAK)
      line_break ? sample.b.byteslice(0, line_break.end(0)) : sample.b
    end

    def wide_encoding?
      WIDE_ENCODINGS.key?(byte_order_mark)
    end

    def encoding_option
      WIDE_ENCODINGS.fetch(byte_order_mark) { encoding == 'UTF-8' ? EncodingOptions::DEFAULT_ENCODING : "#{encoding}:UTF-8" }
    end

    def header_parse_options
      options = { col_sep: col_separator }
      options[:row_sep] = row_separator if row_separator
      options
    end
  end
end
