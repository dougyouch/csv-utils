# CSV Utils

A Ruby library providing a comprehensive set of utilities for manipulating and processing CSV files. This library offers a robust set of tools for comparing, transforming, sorting, and managing CSV data efficiently.

## Features

- **CSV Comparison**: Compare two CSV files and identify differences (creates, updates, and deletes)
- **CSV Transformation**: Transform CSV data with customizable rules
- **CSV Sorting**: Sort CSV files based on specified columns
- **CSV Reporting**: Generate reports from CSV data
- **CSV Iteration**: Efficient iteration over CSV files
- **CSV Extension**: Extend CSV files with additional data
- **CSV Wrapper**: Convenient wrapper for CSV operations

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'csv-utils'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install csv-utils
```

## Usage

### Comparing CSV Files

```ruby
require 'csv_utils'

comparator = CSVUtils::CSVCompare.new('primary.csv', ['updated_at']) do |src, dest|
  src['id'] <=> dest['id']
end

comparator.compare('secondary.csv') do |action, record|
  case action
  when :create
    puts "Create: #{record}"
  when :update
    puts "Update: #{record}"
  when :delete
    puts "Delete: #{record}"
  end
end
```

### Sorting CSV Files

```ruby
sorter = CSVUtils::CSVSort.new('input.csv')
sorter.sort('output.csv', ['id', 'name'])
```

### Transforming CSV Data

```ruby
transformer = CSVUtils::CSVTransformer.new('input.csv')
transformer.transform('output.csv') do |row|
  # Transform row data
  row['new_column'] = row['old_column'].upcase
  row
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/csv-utils.

## License

The gem is available as open source under the terms of the MIT License.
