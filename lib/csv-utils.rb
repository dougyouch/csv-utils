require 'csv'

# Collection of tools for working with CSV files.
module CSVUtils
  autoload :CSVCompare, 'csv_utils/csv_compare'
  autoload :CSVExtender, 'csv_utils/csv_extender'
  autoload :CSVIterator, 'csv_utils/csv_iterator'
  autoload :CSVOptions, 'csv_utils/csv_options'
  autoload :CSVReport, 'csv_utils/csv_report'
  autoload :CSVRow, 'csv_utils/csv_row'
  autoload :CSVSort, 'csv_utils/csv_sort'
  autoload :CSVTransformer, 'csv_utils/csv_transformer'
  autoload :CSVWrapper, 'csv_utils/csv_wrapper'
end
