# frozen_string_literal: true

module CSVUtils
  # Guesses the character encoding of a file without a byte order mark from a sample of its bytes.
  module CharacterEncoding
    # Bytes Windows-1252 leaves undefined; converting them to UTF-8 raises.
    # @return [Regexp]
    WINDOWS_1252_UNDEFINED = /[\x81\x8D\x8F\x90\x9D]/n

    # 'UTF-8' when the sample is valid UTF-8. Otherwise 'Windows-1252', the usual encoding of Excel exports,
    # or 'ISO-8859-1' when the sample has a byte Windows-1252 leaves undefined, since every ISO-8859-1 byte
    # converts to UTF-8.
    # @param sample [String] bytes from the start of the file, ending on a whole character
    # @return [String]
    def self.detect(sample)
      bytes = sample.b
      return 'UTF-8' if bytes.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      return 'ISO-8859-1' if bytes.match?(WINDOWS_1252_UNDEFINED)

      'Windows-1252'
    end
  end
end
