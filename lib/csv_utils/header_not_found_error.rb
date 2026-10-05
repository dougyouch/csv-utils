# frozen_string_literal: true

module CSVUtils
  # Raised when a header the caller named isn't in the file. A RuntimeError, as before this class existed.
  class HeaderNotFoundError < RuntimeError
    include Error

    # @return [String] the header that wasn't found
    attr_reader :header
    # @return [Array<String>] the headers of the file
    attr_reader :headers

    # @param header [String]
    # @param headers [Array<String>]
    def initialize(header, headers)
      @header = header
      @headers = headers
      super("header #{header} not found in #{headers}")
    end
  end
end
