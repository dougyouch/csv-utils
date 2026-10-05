# Architecture

This document describes the internal architecture of the csv-utils gem.

## Overview

csv-utils is a Ruby gem providing utilities for manipulating, debugging, and processing CSV files. The library emphasizes handling malformed CSVs and large file processing through streaming and batch operations.

## Core Design Principles

1. **Streaming Over Loading** - Files are processed row-by-row rather than loading entire files into memory
2. **Resource Management** - Classes close only the files they opened, in `ensure` blocks so an exception in a user block doesn't leak handles
3. **Batch Processing** - Large operations support configurable batch sizes to balance memory and performance
4. **BOM Handling** - Readers strip UTF-8/16/32 byte order marks from the first header through `ByteOrderMark`
5. **One Encoding Rule** - Every class reads with the `encoding:` option (`'bom|utf-8'` by default) and writes in the decoded encoding, through `EncodingOptions`
6. **Autoloading** - `lib/csv-utils.rb` autoloads each class from its own file, so nothing loads until it's used

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CSVUtils Module                          │
├─────────────────────────────────────────────────────────────────┤
│  Detection Layer                                                │
│  ┌─────────────┐  ┌───────────────┐  ┌───────────────────┐      │
│  │ CSVOptions  │  │ ByteOrderMark │  │ CharacterEncoding │      │
│  └─────────────┘  └───────────────┘  └───────────────────┘      │
│  separators, encoding, BOM                                      │
├─────────────────────────────────────────────────────────────────┤
│  I/O Layer                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐         │
│  │ CSVWrapper  │  │ CSVIterator  │  │ EncodingOptions │         │
│  └─────────────┘  └──────────────┘  └─────────────────┘         │
│  ┌─────────────┐                                                │
│  │  RowReader  │  physical lines, BOM, MalformedRowError        │
│  └─────────────┘                                                │
│  Enumerable, RowWrapper; read/write encoding rule               │
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

### CharacterEncoding (Detection)

`detect(sample)` guesses the encoding of a file without a byte order mark: `UTF-8` when the bytes are valid UTF-8, otherwise `Windows-1252`, or `ISO-8859-1` when a byte Windows-1252 leaves undefined (0x81, 0x8D, 0x8F, 0x90, 0x9D) would make the conversion raise.

### EncodingOptions (I/O)

The one place encodings are decided; every class that opens a path goes through it:
- `read(csv_options)` adds `encoding: 'bom|utf-8'` unless one is given
- `write(csv_options)` sets the encoding to the one values were decoded to (`decoded_encoding`): the internal side of `'external:internal'`, otherwise the external one without `bom|`
- `CSVSort` reads its part files back with the write options, which never convert, so any source encoding round-trips
- Modes are always plain `'rb'`/`'wb'`, since CSV raises when a mode and `encoding:` both carry an encoding

### CSVOptions (Detection)

Auto-detects CSV file properties by reading the first line:
- **Column separators**: `\x02`, `\t`, `|`, `,` (checked in order)
- **Row separators**: `\r\n`, `\n`, `\r`
- **Byte order marks**: UTF-8, UTF-16, UTF-32
- **Encoding**: Derived from the BOM, or from the first `SAMPLE_SIZE` (1 MB) bytes through `CharacterEncoding`; a full sample drops its last multibyte character, which may be cut off
- **Columns**: The header line is parsed with `CSV.parse_line`, so quoted separators don't split a header; malformed lines fall back to a plain split
- An empty file reads as an empty line and is not `valid?`
- `to_csv_options` turns the detection into CSV options for `CSV.open` or any class, with an `encoding:` that yields UTF-8 strings: `bom|utf-8`, `Windows-1252:UTF-8`, or for UTF-16/32 files `BOM|UTF-16LE:UTF-8` and the like plus CSV's own row separator detection, since the first line is read as raw bytes

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
- Reads through `RowReader`, so `RowWrapper#lineno` is the physical line a row starts on and `prev_row` is the raw row before the current one
- Opens a path through `CSVWrapper.open` for each call and closes it in an `ensure`, so idle iterators hold no file handle and calls can nest; a CSV passed in is rewound and left open. Only a passed-in CSV is rewound, since rewinding moves back in front of a BOM the `BOM|` mode skipped, and the BOM is stripped from the first row whether it is read as headers or data
- `RowWrapper.create` fills the hash with an index loop rather than `headers.zip(row)`, avoiding an array per column per row
- `CSVIterator.auto_detect(path, full_scan: false)` builds an iterator from `CSVOptions`
- `to_hash` raises `HeaderNotFoundError` for an unknown header

### RowReader (I/O)

Wraps a CSV positioned at its first line and is shared by `CSVIterator` and `CSVCompare`:
- `shift` returns the next row and sets `lineno`, the physical line it starts on: the previous row's end plus one, where each row's end adds the row separators in its raw text (`CSV#line`). CSV's own `lineno` and error line numbers count rows, which fall behind after a quoted line break
- Strips the byte order mark from the first row, whether it's headers or data
- Re-raises `CSV::MalformedCSVError` as `MalformedRowError` (a subclass) with the physical line and the last good row. `CSV::InvalidEncodingError` passes through: CSV raises it when it buffers the bytes, ahead of the rows before them, and its line is already physical

### Errors

`CSVUtils::Error` is a module every raised exception includes, so `rescue CSVUtils::Error` catches them all, while each class keeps the superclass callers rescued before it existed:
- `HeaderNotFoundError < RuntimeError` (`header`, `headers`), from `CSVIterator#to_hash` and `CSVCompare#compare`
- `UnsortedFileError < RuntimeError` (`file`, `lineno`), from `CSVCompare#compare`
- `MalformedRowError < CSV::MalformedCSVError` (`line_number`, `prev_row`), from `RowReader`
- An empty file has `[]` headers; an empty first header cell stays `nil`

### CSVSort (Processing)

External merge sort for large files:
1. **Chunking**: Reads the file in batches (default 100,000 rows) with `each_slice`
2. **Sort chunks**: Each batch is sorted in memory (`sort!` with the block, or `sort_by!` with the key for `sort_by`) and written to a `<output>.N.tmp` file in `tmp_dir`, the output's directory by default
3. **Merge**: Each pass merges consecutive groups of up to `MERGE_WIDTH` (64) files. A merge keeps the next row of every file in an array sorted by key (binary search insertion) and writes the smallest; ties go to the earlier file, so equal keys keep batch order. Up to 64 batches take one pass; the old pairwise merge took log2(batches) passes over the whole file
4. **Keys**: `sort` uses the row as its key and the block as the comparison; `sort_by` computes the key once per row and compares keys with `<=>`
5. **Cleanup**: Merged inputs are deleted after each merge and the final file is moved to the destination. Every temp file is tracked, so an `ensure` removes them all when sorting fails
6. **Default order**: Without a block, rows are compared as arrays (`<=>`)

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
- Reads through `RowReader`; records are `CSVIterator::RowWrapper`s, so they know their line
- Checks each file's order by comparing each record with the previous one in the same file, raising `UnsortedFileError`. The check is enabled per file only when the block compares its first record equal to itself, which a block written for different headers in each file doesn't; `check_order: false` turns it off
- Raises `HeaderNotFoundError` when an update comparison column is missing from either file

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

The scripts are linted by RuboCop (`bin/*` is included explicitly, since they have no `.rb` extension) and covered by subprocess specs in `spec/bin/` (`spec/support/bin_helper.rb` runs them in a temp directory with this checkout's `lib`). `csv-validator`, `csv-duplicate-finder` and `csv-change-eol` open files as `rb:BINARY`: csv 3.3+ reads plain `'rb'` files as UTF-8 when the default external encoding is UTF-8, and those tools need the raw bytes. `csv-find-error` runs the `csv-readline` next to it rather than one on the PATH, passing the physical line from `MalformedRowError`. `csv-find-error`, `csv-grep`, `csv-diff`, `csv-splitter` and `csv-explorer` detect separators and encodings with `CSVOptions`; `csv-splitter` writes parts under temporary names in one pass and renames them once it knows how many there are.

## Encodings

Every class opens paths with a plain `'rb'` or `'wb'` mode and takes the encoding from the `encoding:` CSV option through `EncodingOptions`. Reads default to `'bom|utf-8'`, so values are UTF-8 strings whatever the locale and invalid bytes raise `CSV::InvalidEncodingError`; `'BINARY'` reads raw bytes and `'Windows-1252:UTF-8'` converts. Writes use the decoded encoding, so output is UTF-8 unless the read encoding didn't convert. `CSVReport`, which only writes, defaults to UTF-8. See UPGRADING.md for how this differs from 0.6.

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
