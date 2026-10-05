# frozen_string_literal: true

module CSVUtils
  # Raised by {CSVCompare} when a file isn't sorted the way its compare block expects.
  class UnsortedFileError < RuntimeError
    include Error

    # @return [String] path of the file
    attr_reader :file
    # @return [Integer] physical line of the first record out of order
    attr_reader :lineno

    # @param file [String]
    # @param lineno [Integer]
    def initialize(file, lineno)
      @file = file
      @lineno = lineno
      super("#{file} isn't sorted: the record on line #{lineno} sorts before the one above it")
    end
  end
end
