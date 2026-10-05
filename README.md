# CSV Utils

Streaming tools for CSV files that are too big or too broken to load into memory. Compare two sorted files into create, update and delete actions, sort with an external merge sort, transform and extend rows in batches, and build reports from Ruby objects. Command line tools pinpoint malformed rows and diff, grep, split and validate CSV files.

[![CI](https://github.com/dougyouch/csv-utils/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/dougyouch/csv-utils/actions/workflows/ci.yml)
[![Coverage](https://raw.githubusercontent.com/dougyouch/csv-utils/badges/coverage.svg)](https://github.com/dougyouch/csv-utils/actions/workflows/ci.yml)
[![Branch Coverage](https://raw.githubusercontent.com/dougyouch/csv-utils/badges/branches.svg)](https://github.com/dougyouch/csv-utils/actions/workflows/ci.yml)

[API reference](https://rubydoc.info/gems/csv-utils) · [Changelog](CHANGELOG.md) · [Architecture](ARCHITECTURE.md)

## Features

- **CSV Comparison**: Compare two CSV files and identify differences (creates, updates, and deletes)
- **CSV Transformation**: Transform CSV data with a chainable pipeline
- **CSV Sorting**: Sort large CSV files using external merge sort
- **CSV Reporting**: Generate CSV reports from Ruby objects
- **CSV Row**: Mixin for defining CSV-serializable objects
- **CSV Row Matcher**: Filter CSV rows using regex patterns across columns
- **CSV Iteration**: Efficient iteration over CSV files with batch support
- **CSV Extension**: Extend CSV files with additional columns
- **CSV Options**: Auto-detect CSV file properties (separators, encoding, BOM)
- **Byte Order Marks**: UTF-8, UTF-16 and UTF-32 byte order marks are stripped from the first header
- **CLI Tools**: Command-line utilities for CSV debugging and manipulation

## Installation

Requires Ruby 3.3 or newer. Add this line to your application's Gemfile:

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

Pass CSV options as the third argument to read both files with them, e.g. tab separated files:

```ruby
CSVUtils::CSVCompare.new('primary.tsv', ['updated_at'], col_sep: "\t") { |src, dest| src['id'] <=> dest['id'] }
```

**Note**: Both CSV files must be sorted by the same key columns for comparison to work correctly, and the block must compare them in that same order.

The block compares the key columns of a primary and a secondary record like `<=>`. Records only in the primary file are yielded as `:create`, records only in the secondary file as `:delete`, and matching records as `:update` when any of the update comparison columns differ. Without update comparison columns, no updates are yielded.

### Sorting CSV Files

Sort large CSV files using external merge sort:

```ruby
require 'csv-utils'

sorter = CSVUtils::CSVSort.new('input.csv', 'output.csv', true)  # true = has headers
sorter.sort(100_000) { |a, b| a.first.to_i <=> b.first.to_i }    # batch size, comparison block

# without a block, rows are compared as arrays of strings
sorter.sort
```

Batches are sorted into temporary `output.csv.part.N` files next to the output, which are merged in pairs. The temporary files are removed when the sort finishes or fails.

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

Without `read_headers`, every row is treated as data and the output has no header row. `process` closes the files it opened, even when a step raises.

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

# Without a block, each returns an Enumerator
iterator.each.with_index { |row, idx| puts "#{idx}: #{row['name']}" }
```

Line numbers count the header row as line 1, so they match what an editor shows. `headers` returns `[]` for an empty file.

### Matching CSV Rows

Filter CSV rows using regex patterns:

```ruby
require 'csv-utils'

# Match against all columns
matcher = CSVUtils::CSVRowMatcher.new(/error/i)

# Or match only specific columns
matcher = CSVUtils::CSVRowMatcher.new(/error/i, ['status', 'message'])

# Use with iteration
iterator = CSVUtils::CSVIterator.new('logs.csv')
error_rows = iterator.select(&matcher)

# Use directly
row = { 'id' => '123', 'status' => 'Error', 'message' => 'Connection failed' }
matcher.match?(row)  # => true
```

The matcher can be used with any Enumerable method via `to_proc`:

```ruby
rows.select(&matcher)  # rows matching the pattern
rows.reject(&matcher)  # rows not matching the pattern
rows.find(&matcher)    # first matching row
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

Supported column separators: `\x02`, `\t`, `|`, `,` (the first one found in the header line wins)
Supported row separators: `\r\n`, `\n`, `\r`

Headers are parsed as a CSV row, so a quoted header like `"Last, First"` counts as one column. An empty file isn't valid.

### Encodings and Byte Order Marks

Files are opened with mode `'rb'`. With csv 3.3 and later, when Ruby's default external encoding is UTF-8 (the usual case), CSV reads `'rb'` files as UTF-8 and raises `CSV::InvalidEncodingError` on bytes that aren't valid UTF-8. To read a file's bytes as is, pass an explicit encoding:

```ruby
iterator = CSVUtils::CSVIterator.new('latin1.csv', {}, 'rb:BINARY')
comparator = CSVUtils::CSVCompare.new('primary.csv', ['updated_at'], encoding: 'BINARY') { |src, dest| src['id'] <=> dest['id'] }
sorter = CSVUtils::CSVSort.new('input.csv', 'output.csv', true, encoding: 'BINARY')
```

`CSVSort`, `CSVExtender` and `CSVTransformer` take CSV options as their last argument and `CSVIterator` takes them second; they're passed to `CSV.open` for file paths.

`CSVUtils::ByteOrderMark` detects and strips UTF-8, UTF-16 and UTF-32 byte order marks; `CSVIterator`, `CSVCompare` and `CSVOptions` use it to clean the first header.

## CLI Tools

The gem installs command-line utilities for CSV debugging:

| Command | Description |
|---------|-------------|
| `csv-find-error` | Locate the first malformed row and show it with `csv-readline` |
| `csv-readline` | Print the columns of a line, flagging stray quotes |
| `csv-validator` | Report rows with the wrong number of columns and values that aren't UTF-8 |
| `csv-diff` | Compare two CSV files by a unique key |
| `csv-grep` | Search columns for a pattern |
| `csv-splitter` | Split a large CSV file into parts |
| `csv-explorer` | Open an IRB session with the file loaded as a `CSVIterator` |
| `csv-duplicate-finder` | Find duplicate rows |
| `csv-change-eol` | Rewrite a file with a different line ending |

```bash
# find the first malformed row
csv-find-error data.csv

# print the row on line 1042, read as 3 lines for values with embedded newlines, including empty columns
csv-readline --all data.csv 1042 3

# compare by the id column, ignoring updated_at; writes diff-results-old.csv
csv-diff -u id -i updated_at old.csv new.csv

# case-insensitive search of the email and name columns, first 10 matches
csv-grep -s 'smith' -c email,name -i -l 10 data.csv

# split into files of 100,000 rows, each with the header
csv-splitter -r 100000 data.csv

# find rows that are duplicates apart from id; writes duplicates-data.csv
csv-duplicate-finder -i id data.csv

# end every row with |^| and a newline
csv-change-eol data.csv 7C5E7C0A
```

`csv-validator` needs the `rchardet` gem (`gem install rchardet`) to guess the encoding of values that aren't UTF-8. It writes the converted values to `utf8-correction.csv`.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then:

```bash
bundle exec rspec       # run the tests
bundle exec rubocop     # run the linter
bundle exec yard stats --list-undoc   # check the API docs
```

CI runs RuboCop, requires every public class, module, constant and method to have a YARD doc comment, and runs the specs on Ruby 3.3 and the `.ruby-version` Ruby with 100% line and branch coverage (`CI=1 bundle exec rspec` enforces it locally).

Releases are automated by [release-please](https://github.com/googleapis/release-please) from [conventional commits](https://www.conventionalcommits.org/): merging its release PR tags the version and publishes the gem.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dougyouch/csv-utils.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
