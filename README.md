# CSV Utils

A Ruby library providing a comprehensive set of utilities for manipulating and processing CSV files. This library offers a robust set of tools for comparing, transforming, sorting, and managing CSV data efficiently.

## Features

- **CSV Comparison**: Compare two CSV files and identify differences (creates, updates, and deletes)
- **CSV Transformation**: Transform CSV data with a chainable pipeline
- **CSV Sorting**: Sort large CSV files using external merge sort
- **CSV Reporting**: Generate CSV reports from Ruby objects
- **CSV Row**: Mixin for defining CSV-serializable objects
- **CSV Iteration**: Efficient iteration over CSV files with batch support
- **CSV Extension**: Extend CSV files with additional columns
- **CSV Options**: Auto-detect CSV file properties (separators, encoding, BOM)
- **CLI Tools**: Command-line utilities for CSV debugging and manipulation

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

Compare two sorted CSV files to identify creates, updates, and deletes:

```ruby
require 'csv-utils'

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

**Note**: Both CSV files must be sorted by the same key columns for comparison to work correctly.

### Sorting CSV Files

Sort large CSV files using external merge sort:

```ruby
require 'csv-utils'

sorter = CSVUtils::CSVSort.new('input.csv', 'output.csv', true)  # true = has headers
sorter.sort(100_000) { |a, b| a.first.to_i <=> b.first.to_i }    # batch size, comparison block
```

### Transforming CSV Data

Transform CSV data using a chainable pipeline:

```ruby
require 'csv-utils'

CSVUtils::CSVTransformer.new('input.csv', 'output.csv')
  .read_headers
  .select { |row, headers, _| row[0].to_i > 100 }                    # filter rows
  .map(['ID', 'Name']) { |row, headers, _| [row[0], row[1].upcase] } # transform rows
  .append(['Email']) { |row, headers, _| ["#{row[1].downcase}@example.com"] }
  .process(10_000)  # batch size
```

Available pipeline methods:
- `select { |row, headers, additional_data| }` - Keep rows where block returns true
- `reject { |row, headers, additional_data| }` - Remove rows where block returns true
- `map(new_headers) { |row, headers, additional_data| }` - Transform rows
- `append(additional_headers) { |row, headers, additional_data| }` - Add columns
- `additional_data { |batch, headers| }` - Compute batch-level data for use in other steps
- `each { |row, headers, additional_data| }` - Side effects without modification
- `set_headers(headers)` - Override output headers

### CSV Row and Report

Define CSV-serializable objects and generate reports:

```ruby
require 'csv-utils'

class User
  include CSVUtils::CSVRow

  attr_accessor :id, :name, :email

  csv_column :id, header: 'ID'
  csv_column :name
  csv_column(:email) { email.downcase }

  def initialize(id, name, email)
    @id = id
    @name = name
    @email = email
  end
end

users = [
  User.new(1, 'Alice', 'ALICE@example.com'),
  User.new(2, 'Bob', 'BOB@example.com')
]

# Generate CSV report
CSVUtils::CSVReport.new('users.csv', User) do |report|
  users.each { |user| report << user }
end
```

The `csv_column` method accepts:
- A symbol referencing a method: `csv_column :name`
- A custom header: `csv_column :id, header: 'ID'`
- A block for computed values: `csv_column(:email) { email.downcase }`
- A proc: `csv_column :count, proc: Proc.new { data[:count] }`

#### Generating Reports from ActiveRecord Models

A powerful pattern is to subclass an ActiveRecord model with `CSVRow` for generating reports directly from database records:

```ruby
require 'csv-utils'

class UserCSVRow < User
  include CSVUtils::CSVRow

  csv_column :id
  csv_column :name
  csv_column :email
  csv_column :num_orders      # computed column
  csv_column :total_revenue   # computed column

  def num_orders
    orders.count
  end

  def total_revenue
    orders.sum(:amount)
  end

  # free up memory during large iterations
  def clear!
    @association_cache = {}
  end
end

# Generate report using ActiveRecord scopes
CSVUtils::CSVReport.new('user_report.csv', UserCSVRow) do |report|
  UserCSVRow.where(active: true).find_each do |user|
    report << user
    user.clear!
  end
end
```

This pattern provides:
- **Inherited attributes**: All model columns available without redefinition
- **Association access**: Query related tables for computed columns
- **ActiveRecord scopes**: Use `.where`, `.includes`, `.find_each` directly
- **Memory efficiency**: The `clear!` method frees association cache during iteration

### Iterating CSV Files

Efficiently iterate over CSV files:

```ruby
require 'csv-utils'

iterator = CSVUtils::CSVIterator.new('data.csv')

# Iterate row by row
iterator.each do |row|
  puts "Line #{row.lineno}: #{row['name']}"
end

# Process in batches
iterator.each_batch(1_000) do |batch|
  # Process batch of rows
end

# Build a lookup hash
lookup = iterator.to_hash('id', 'name')  # { 'id_value' => 'name_value', ... }
```

### Extending CSV Files

Add columns to an existing CSV:

```ruby
require 'csv-utils'

extender = CSVUtils::CSVExtender.new('input.csv', 'output.csv')

# Row by row
extender.append(['new_column']) do |row, headers|
  [row[0].upcase]  # return array of new column values
end

# Or in batches (useful for external lookups)
extender.append_in_batches(['status'], 1_000) do |batch, headers|
  # Return array of arrays, one per row in batch
  batch.map { |row| ['active'] }
end
```

### Auto-detecting CSV Options

Detect CSV file properties automatically:

```ruby
require 'csv-utils'

options = CSVUtils::CSVOptions.new('data.csv')

options.valid?         # true if separators detected
options.col_separator  # detected column separator
options.row_separator  # detected row separator
options.encoding       # detected encoding (UTF-8, UTF-16, UTF-32)
options.columns        # number of columns
options.byte_order_mark # BOM if present
```

Supported column separators: `\x02`, `\t`, `|`, `,`
Supported row separators: `\r\n`, `\n`, `\r`

## CLI Tools

The gem includes command-line utilities for CSV debugging:

| Command | Description |
|---------|-------------|
| `csv-find-error` | Locate malformed CSV errors with context |
| `csv-readline` | Read specific lines from a CSV file |
| `csv-validator` | Validate CSV structure |
| `csv-diff` | Compare two CSV files |
| `csv-grep` | Search within CSV content |
| `csv-splitter` | Split large CSV files into parts |
| `csv-explorer` | Interactive CSV exploration |
| `csv-duplicate-finder` | Find duplicate rows |
| `csv-change-eol` | Convert line endings |

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dougyouch/csv-utils.

## License

The gem is available as open source under the terms of the MIT License.
