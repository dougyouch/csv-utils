# frozen_string_literal: true

module CSVUtils
  # Detects and strips the byte order mark at the start of a CSV file.
  module ByteOrderMark
    # Byte order marks, as binary strings, to the encoding they indicate.
    # This list is from https://en.wikipedia.org/wiki/Byte_order_mark.
    # UTF-32 LE starts with the UTF-16 LE mark, so longer marks come first.
    # @return [Hash{String => String}]
    ENCODINGS = {
      (+"\x00\x00\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'UTF-32',
      (+"\xFF\xFE\x00\x00").force_encoding('ASCII-8BIT').freeze => 'UTF-32',
      (+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT').freeze => 'UTF-8',
      (+"\xFE\xFF").force_encoding('ASCII-8BIT').freeze => 'UTF-16',
      (+"\xFF\xFE").force_encoding('ASCII-8BIT').freeze => 'UTF-16'
    }.freeze

    # The byte order mark the string starts with. Compares bytes, so it works whatever the string's encoding is.
    # @param str [String]
    # @return [String, nil] the mark as a binary string
    def self.detect(str)
      prefix = str.byteslice(0, 4).b
      ENCODINGS.keys.detect { |bom| prefix.start_with?(bom) }
    end

    # The string without its leading byte order mark, in its original encoding.
    # @param str [String]
    # @return [String]
    def self.strip(str)
      bom = detect(str)
      bom ? str.byteslice(bom.bytesize..) : str
    end
  end
end
