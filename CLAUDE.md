# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
bundle install          # Install dependencies
bundle exec rspec       # Run all tests
bundle exec rspec spec/csv_utils/csv_compare_spec.rb  # Run single test file
bundle exec rubocop     # Run linter
```

## Architecture

This is a Ruby gem (`csv-utils`) providing utilities for manipulating and debugging CSV files, particularly malformed ones.

### Core Classes (lib/csv_utils/)

- **CSVOptions** - Auto-detects CSV file properties: column separator, row separator, byte order marks, and encoding. Handles various separators (`\x02`, `\t`, `|`, `,`) and BOMs (UTF-8, UTF-16, UTF-32).
- **CSVWrapper** - Resource-safe wrapper around Ruby's CSV class that manages file handle lifecycle.
- **CSVCompare** - Compares two sorted CSV files, yielding `:create`, `:update`, or `:delete` actions.
- **CSVSort** - Sorts CSV files by specified columns.
- **CSVTransformer** - Applies row transformations with block-based processing.
- **CSVExtender** - Extends CSV files with additional columns/data.
- **CSVReport** - Generates reports from CSV data.
- **CSVIterator** - Efficient CSV iteration.
- **CSVRow** - Row-level operations.

### CLI Tools (bin/)

Standalone utilities for CSV debugging and manipulation:
- `csv-find-error` - Locates malformed CSV errors
- `csv-readline` - Reads specific lines from CSV
- `csv-validator` - Validates CSV structure
- `csv-diff` - Compares CSV files
- `csv-grep` - Searches within CSV files
- `csv-splitter` - Splits large CSV files
- `csv-explorer` - Interactive CSV exploration
- `csv-duplicate-finder` - Finds duplicate rows
- `csv-change-eol` - Converts line endings

### Dependencies

- `csv` - Ruby's standard CSV library
- `inheritance-helper` - Class inheritance utilities

## Code Commits

Format using angular formatting:
```
<type>(<scope>): <short summary>
```
- **type**: build|ci|docs|feat|fix|perf|refactor|test
- **scope**: The feature or component of the service we're working on
- **summary**: Summary in present tense. Not capitalized. No period at the end.

## Documentation Maintenance

When modifying the codebase, keep documentation in sync:
- **ARCHITECTURE.md** - Update when adding/removing classes, changing component relationships, or altering data flow patterns
- **README.md** - Update when adding new features, changing public APIs, or modifying usage examples
- **Code comments** - Update inline documentation when changing method signatures or behavior
