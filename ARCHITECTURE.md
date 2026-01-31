# Architecture

This document describes the internal architecture of the csv-utils gem.

## Overview

csv-utils is a Ruby gem providing utilities for manipulating, debugging, and processing CSV files. The library emphasizes handling malformed CSVs and large file processing through streaming and batch operations.

## Core Design Principles

1. **Streaming Over Loading** - Files are processed row-by-row rather than loading entire files into memory
2. **Resource Management** - CSVWrapper ensures proper file handle lifecycle management
3. **Batch Processing** - Large operations support configurable batch sizes to balance memory and performance
4. **BOM Handling** - All readers strip UTF-8/16/32 byte order marks from headers

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CSVUtils Module                          │
├─────────────────────────────────────────────────────────────────┤
│  Detection Layer                                                │
│  ┌─────────────┐                                                │
│  │ CSVOptions  │  Auto-detects separators, encoding, BOM       │
│  └─────────────┘                                                │
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
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### CSVOptions (Detection)

Auto-detects CSV file properties by reading the first line:
- **Column separators**: `\x02`, `\t`, `|`, `,` (checked in order)
- **Row separators**: `\r\n`, `\n`, `\r`
- **Byte order marks**: UTF-8, UTF-16, UTF-32
- **Encoding**: Derived from BOM or defaults to UTF-8

### CSVWrapper (I/O)

Resource-safe wrapper around Ruby's CSV class:
- Tracks whether it opened the file (vs receiving an existing handle)
- Only closes files it opened (`@close_when_done`)
- Provides uniform interface for both file paths and CSV objects

### CSVIterator (I/O)

Enumerable wrapper for CSV reading:
- **RowWrapper**: Hash subclass that preserves line numbers for error reporting
- `each_batch(size)`: Yields rows in configurable batches
- `to_hash(key, value)`: Builds lookup hash from CSV columns
- Tracks `prev_row` for error context

### CSVSort (Processing)

External merge sort for large files:
1. **Chunking**: Reads file in batches (default 100,000 rows)
2. **Sort chunks**: Each batch sorted in memory, written to `.part.N` temp files
3. **Merge**: Temp files merged pairwise into `.merge.N` files until one remains
4. **Cleanup**: Temp files deleted, final file moved to destination

### CSVTransformer (Processing)

Chainable transformation pipeline:
- `select(&block)` / `reject(&block)` - Filter rows
- `map(new_headers, &block)` - Transform rows
- `append(headers, &block)` - Add columns
- `additional_data(&block)` - Compute batch-level data accessible to other steps
- `each(&block)` - Side effects without modification
- Processes in batches (default 10,000 rows)

### CSVExtender (Processing)

Appends columns to existing CSV:
- `append(headers)` - Row-by-row column addition
- `append_in_batches(headers, size)` - Batch processing for external lookups

### CSVCompare (Analysis)

Compares two **pre-sorted** CSV files:
- Yields `:create`, `:update`, `:delete` actions
- Requires a comparison proc for row identity
- Optional `update_comparison_columns` to detect changes (e.g., `updated_at`)
- Both files must be sorted by the same key columns

### CSVReport (Analysis)

Builds CSV output from objects:
- Accepts file path or existing CSV object
- Block-based generation with automatic close
- Works with CSVRow-enabled objects

### CSVRow (Mixin)

Module for defining CSV-serializable objects:
- `csv_column(name, options, &block)` - Define columns declaratively
- Uses `inheritance-helper` for inherited column definitions
- Columns can reference methods or use custom procs

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
