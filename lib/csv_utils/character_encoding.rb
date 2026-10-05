# frozen_string_literal: true

module CSVUtils
  # Guesses the character encoding of a file without a byte order mark from its bytes.
  module CharacterEncoding
    # Bytes Windows-1252 leaves undefined; converting them to UTF-8 raises.
    # @return [Regexp]
    WINDOWS_1252_UNDEFINED = /[\x81\x8D\x8F\x90\x9D]/n

    # The last character of a chunk when it's multibyte, whole or cut off: a lead byte and continuation bytes.
    TRAILING_MULTIBYTE_CHAR = /[\xC0-\xFF][\x80-\xBF]*\z/n
    private_constant :TRAILING_MULTIBYTE_CHAR

    # 'UTF-8' when the bytes are valid UTF-8. Otherwise 'Windows-1252', the usual encoding of Excel exports,
    # or 'ISO-8859-1' when they have a byte Windows-1252 leaves undefined, since every ISO-8859-1 byte
    # converts to UTF-8.
    # @param sample [String] bytes from the start of the file
    # @param truncated [Boolean] whether the sample was cut off, so its last character may be incomplete
    # @return [String]
    def self.detect(sample, truncated: false)
      scan([sample], truncated)
    end

    # Like {.detect}, for a file read in chunks, so it can check a whole file without holding it in memory.
    # A character split between chunks is checked whole.
    # @param chunks [Enumerable<String>] the file's bytes in order
    # @return [String]
    def self.detect_stream(chunks)
      scan(chunks, false)
    end

    # @api private
    # @param chunks [Enumerable<String>]
    # @param truncated [Boolean] whether to ignore an incomplete character at the end
    # @return [String]
    def self.scan(chunks, truncated)
      utf8 = true
      undefined = false
      carry = ''.b
      chunks.each do |chunk|
        bytes = carry + chunk.b
        whole, carry = split_trailing_char(bytes)
        utf8 &&= whole.force_encoding(Encoding::UTF_8).valid_encoding?
        undefined ||= bytes.match?(WINDOWS_1252_UNDEFINED)
        break unless utf8 || !undefined
      end
      utf8 &&= truncated || carry.force_encoding(Encoding::UTF_8).valid_encoding?
      encoding_name(utf8, undefined)
    end

    # @api private
    # @param bytes [String] binary
    # @return [Array(String, String)] the bytes before their last multibyte character, and that character
    def self.split_trailing_char(bytes)
      tail_start = [bytes.bytesize - 4, 0].max
      idx = bytes.byteslice(tail_start..) =~ TRAILING_MULTIBYTE_CHAR
      return [bytes.dup, ''.b] unless idx

      [bytes.byteslice(0, tail_start + idx), bytes.byteslice((tail_start + idx)..)]
    end

    # @api private
    # @param utf8 [Boolean]
    # @param undefined [Boolean]
    # @return [String]
    def self.encoding_name(utf8, undefined)
      return 'UTF-8' if utf8
      return 'ISO-8859-1' if undefined

      'Windows-1252'
    end
  end
end
