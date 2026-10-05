# frozen_string_literal: true

module CSVUtils
  # The one place the library decides how files are decoded and encoded. Every class reads with the
  # :encoding CSV option, 'bom|utf-8' by default, so values are UTF-8 strings whatever the locale, and
  # writes in the encoding the values were decoded to, so reading 'Windows-1252:UTF-8' writes UTF-8.
  # File modes never carry an encoding: CSV raises when the mode and the :encoding option both have one.
  #
  # @example
  #   CSV.open(path, 'rb', **CSVUtils::EncodingOptions.read(col_sep: "\t"))
  module EncodingOptions
    # @return [String] the :encoding option used for reading when none is given
    DEFAULT_ENCODING = 'bom|utf-8'

    # Options for reading: the given options with the default :encoding when they have none.
    # @param csv_options [Hash]
    # @return [Hash]
    def self.read(csv_options)
      { encoding: DEFAULT_ENCODING }.merge(csv_options)
    end

    # Options for writing values read with csv_options: the :encoding is the one values were decoded to.
    # @param csv_options [Hash]
    # @return [Hash]
    def self.write(csv_options)
      csv_options.merge(encoding: decoded_encoding(read(csv_options)[:encoding]))
    end

    # The encoding of strings read with an :encoding option: the internal encoding of 'external:internal',
    # otherwise the external one, without a 'bom|' prefix.
    # @example
    #   CSVUtils::EncodingOptions.decoded_encoding('Windows-1252:UTF-8') # => 'UTF-8'
    #   CSVUtils::EncodingOptions.decoded_encoding('bom|utf-8') # => 'utf-8'
    # @param encoding [String, Encoding]
    # @return [String]
    def self.decoded_encoding(encoding)
      encoding.to_s.split(':').last.sub(/\Abom\|/i, '')
    end
  end
end
