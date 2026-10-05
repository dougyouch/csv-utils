# Architecture

This document describes the internal architecture of the csv-utils gem.

## Overview

csv-utils is a Ruby gem providing utilities for manipulating, debugging, and processing CSV files. The library emphasizes handling malformed CSVs and large file processing through streaming and batch operations.

## Core Design Principles

1. **Streaming Over Loading** - Files are processed row-by-row rather than loading entire files into memory
2. **Resource Management** - Classes close only the files they opened, in `ensure` blocks so an exception in a user block doesn't leak handles
3. **Batch Processing** - Large operations support configurable batch sizes to balance memory and performance
4. **BOM Handling** - Readers strip UTF-8/16/32 byte order marks from the first header through `ByteOrderMark`
5. **Autoloading** - `lib/csv-utils.rb` autoloads each class from its own file, so nothing loads until it's used

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CSVUtils Module                          │
├─────────────────────────────────────────────────────────────────┤
│  Detection Layer                                                │
│  ┌─────────────┐  ┌───────────────┐                             │
│  │ CSVOptions  │  │ ByteOrderMark │  separators, encoding, BOM  │
│  └─────────────┘  └───────────────┘                             │
├─────────────────────────────────────────────────────────────────┤
│  I/O Layer                                                      │
│  ┌─────────────┐  ┌──────────────┐                              │
│  │ CSVWrapper  │  │ CSVIterator  │  Enumerable, RowWrapper     │
│  └─────────────┘  └──────────────┘                              │
├─────────────────────────────────────────────────────────────────┤
│  Processing Layer                                               │
│  ┌───────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │ CSVTransformer│  │ CSVExtender │  │  CSVSort    │           │
│  │ (pipeline)    │  │ (append)    │  │ (merge sort)│           │
│  └───────────────┘  └─────────────┘  └─────────────┘           │
├─────────────────────────────────────────────────────────────────┤
│  Analysis Layer                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ CSVCompare  │  │  CSVReport  │  │   CSVRow    │             │
│  │ (diff)      │  │  (generate) │  │  (mixin)    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌───────────────┐                                             │
│  │ CSVRowMatcher │  regex filter usable as a block (&matcher)  │
│  └───────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### ByteOrderMark (Detection)

Module functions shared by every reader:
- `ENCODINGS` maps each mark (binary string) to its encoding, longest first, because the UTF-32 LE mark starts with the UTF-16 LE one
- `detect(str)` / `strip(str)` compare bytes, so they work on binary and UTF-8 strings alike; `strip` keeps the string's encoding

### CSVOptions (Detection)

Auto-detects CSV file properties by reading the first line:
- **Column separators**: `\x02`, `\t`, `|`, `,` (checked in order)
- **Row separators**: `\r\n`, `\n`, `\r`
- **Byte order marks**: UTF-8, UTF-16, UTF-32
- **Encoding**: Derived from BOM or defaults to UTF-8
- **Columns**: The header line is parsed with `CSV.parse_line`, so quoted separators don't split a header; malformed lines fall back to a plain split
- An empty file reads as an empty line and is not `valid?`

### CSVWrapper (I/O)

Resource-safe wrapper around Ruby's CSV class:
- Tracks whether it opened the file (vs receiving an existing handle)
- Only closes files it opened (`@close_when_done`)
- Provides uniform interface for both file paths and CSV objects (specs pass plain arrays of rows)
- `CSVWrapper.open` with a block closes in an `ensure` and returns the block's value

### CSVIterator (I/O)

Enumerable wrapper for CSV reading:
- **RowWrapper**: Hash subclass that preserves line numbers for error reporting
- `each_batch(size)`: Yields rows in configurable batches
- `to_hash(key, value)`: Builds lookup hash from CSV columns
- `each` without a block returns an Enumerator
- Tracks `prev_row` for error context
- An empty file has `[]` headers; an empty first header cell stays `nil`

### CSVSort (Processing)

External merge sort for large files:
1. **Chunking**: Reads file in batches (default 100,000 rows)
2. **Sort chunks**: Each batch sorted in memory, written to `.part.N` temp files
3. **Merge**: Temp files merged pairwise into `.merge.N` files until one remains
4. **Cleanup**: Merged inputs are deleted as it goes and the final file is moved to the destination. Files stay in `@csv_part_files` until merged, so an `ensure` removes every temp file when sorting fails
5. **Default order**: Without a block, rows are compared as arrays (`<=>`)

### CSVTransformer (Processing)

Chainable transformation pipeline:
- `select(&block)` / `reject(&block)` - Filter rows
- `map(new_headers, &block)` - Transform rows
- `append(headers, &block)` - Add columns
- `additional_data(&block)` - Compute batch-level data accessible to other steps
- `each(&block)` - Side effects without modification
- Processes in batches (default 10,000 rows)
- Each step is stored as `[type, headers_at_that_point, block]` and dispatched to a `process_<type>_step` method

### CSVExtender (Processing)

Appends columns to existing CSV:
- `append(headers)` - Row-by-row column addition
- `append_in_batches(headers, size)` - Batch processing for external lookups

### CSVCompare (Analysis)

Compares two **pre-sorted** CSV files:
- Yields `:create`, `:update`, `:delete` actions
- Requires a comparison proc for row identity
- Optional `update_comparison_columns` to detect changes (e.g., `updated_at`)
- Optional `csv_options` passed to `CSV.open` for both files
- Both files must be sorted by the same key columns
- Holds one record from each file and advances whichever side is behind until both run out, so the last record of the longer file is always yielded

### CSVReport (Analysis)

Builds CSV output from objects:
- Accepts file path or existing CSV object
- Block-based generation with automatic close
- Works with CSVRow-enabled objects

### CSVRowMatcher (Analysis)

Matches row hashes against a regex in all columns or a list of headers; `to_proc` lets it be passed to `select`, `reject` and `find`.

### CSVRow (Mixin)

Module for defining CSV-serializable objects:
- `csv_column(name, options, &block)` - Define columns declaratively
- Uses `inheritance-helper` for inherited column definitions
- Columns can reference methods or use custom procs
- `csv_column` copies its options hash, so one hash can be shared between columns

## CLI Tools

Standalone executables for CSV debugging:

| Tool | Purpose |
|------|---------|
| `csv-find-error` | Locates malformed CSV errors, shows context |
| `csv-readline` | Reads specific line numbers |
| `csv-validator` | Validates CSV structure |
| `csv-diff` | Compares two CSV files |
| `csv-grep` | Searches within CSV content |
| `csv-splitter` | Splits large files into parts |
| `csv-explorer` | Interactive CSV exploration |
| `csv-duplicate-finder` | Identifies duplicate rows |
| `csv-change-eol` | Converts line endings |

The scripts are excluded from RuboCop and covered by subprocess specs in `spec/bin/` (`spec/support/bin_helper.rb` runs them in a temp directory with this checkout's `lib`). `csv-validator`, `csv-duplicate-finder` and `csv-change-eol` open files as `rb:BINARY`: csv 3.3+ reads plain `'rb'` files as UTF-8 when the default external encoding is UTF-8, and those tools need the raw bytes. `csv-find-error` runs the `csv-readline` next to it rather than one on the PATH.

## Encodings

The library opens files with mode `'rb'` and no explicit encoding. Under csv 3.3+ with a UTF-8 default external encoding, CSV then applies `bom|utf-8`, so values are UTF-8 strings and invalid bytes raise `CSV::InvalidEncodingError`. `CSVIterator` takes a `mode` argument (`'rb:BINARY'` for raw bytes) and `CSVCompare`, `CSVSort`, `CSVExtender` and `CSVTransformer` take CSV options (e.g. `encoding: 'BINARY'`).

## Data Flow Patterns

### Comparison Flow (requires pre-sorting)
```
primary.csv ──┐
              ├── CSVCompare ──> :create/:update/:delete actions
secondary.csv─┘
```

### Transformation Flow
```
input.csv ──> CSVTransformer ──[select]──[map]──[append]──> output.csv
```

### Sort Flow (external merge sort)
```
large.csv ──> [chunk & sort] ──> .part.0, .part.1, ...
                                      │
                    [pairwise merge] ──┘
                           │
                    sorted.csv
```

## Testing and CI

Specs mirror `lib/` under `spec/csv_utils/`, plus `spec/bin/` for the scripts and `spec/csv_utils_gemspec_spec.rb` for packaging. SimpleCov measures line and branch coverage of `lib/`; with `CI` set, anything under 100% fails the run. CI also runs RuboCop and requires complete YARD docs, and pushes to `master` publish the coverage badges to the `badges` branch. Releases go through release-please (`.github/workflows/release.yml`), which bumps `lib/csv_utils/version.rb` and `CHANGELOG.md` and publishes the gem.
