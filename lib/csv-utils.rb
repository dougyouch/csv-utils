require 'csv'

# Collection of tools for working with CSV files.
module CSVUtils
  autoload :CSVExtender, 'csv_utils/csv_extender'
  autoload :CSVOptions, 'csv_utils/csv_options'
  autoload :CSVReport, 'csv_utils/csv_report'
  autoload :CSVRow, 'csv_utils/csv_row'
end
