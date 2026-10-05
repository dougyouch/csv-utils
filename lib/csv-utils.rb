# frozen_string_literal: true

require 'csv'

# Tools for comparing, sorting, transforming and debugging CSV files, including ones too large to load
# into memory. Each class is autoloaded on first use.
module CSVUtils
  autoload :ByteOrderMark, 'csv_utils/byte_order_mark'
  autoload :CharacterEncoding, 'csv_utils/character_encoding'
  autoload :EncodingOptions, 'csv_utils/encoding_options'
  autoload :Error, 'csv_utils/error'
  autoload :HeaderNotFoundError, 'csv_utils/header_not_found_error'
  autoload :MalformedRowError, 'csv_utils/malformed_row_error'
  autoload :RowReader, 'csv_utils/row_reader'
  autoload :UnsortedFileError, 'csv_utils/unsorted_file_error'
  autoload :CSVCompare, 'csv_utils/csv_compare'
  autoload :CSVExtender, 'csv_utils/csv_extender'
  autoload :CSVIterator, 'csv_utils/csv_iterator'
  autoload :CSVOptions, 'csv_utils/csv_options'
  autoload :CSVReport, 'csv_utils/csv_report'
  autoload :CSVRow, 'csv_utils/csv_row'
  autoload :CSVRowMatcher, 'csv_utils/csv_row_matcher'
  autoload :CSVSort, 'csv_utils/csv_sort'
  autoload :CSVTransformer, 'csv_utils/csv_transformer'
  autoload :CSVWrapper, 'csv_utils/csv_wrapper'
end
