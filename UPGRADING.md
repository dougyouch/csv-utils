# Upgrading

## From 0.6 to 0.7

0.7 handles encodings the same way in every class:

- **Reading:** files are decoded with the `encoding:` CSV option, which defaults to `'bom|utf-8'`. Values are UTF-8 strings no matter what the process's locale is.
- **Writing:** output is written in the encoding the values were decoded to. A file read with `encoding: 'Windows-1252:UTF-8'` is written as UTF-8.
- **One place to set it:** the encoding always goes in the `encoding:` option, never in a file mode. CSV raises `ArgumentError: encoding specified twice` when both have one.

`CSVUtils::EncodingOptions` holds these rules, and `CSVUtils::CSVOptions#to_csv_options` can work out the encoding for you.

### Breaking changes

#### `CSVIterator` no longer takes a file mode

The third argument, `mode`, has been removed. Pass the encoding as a CSV option instead:

| 0.6 | 0.7 |
|---|---|
| `CSVIterator.new(path, {}, 'rb:BINARY')` | `CSVIterator.new(path, encoding: 'BINARY')` |
| `CSVIterator.new(path, { col_sep: "\t" }, 'rb:BINARY')` | `CSVIterator.new(path, col_sep: "\t", encoding: 'BINARY')` |
| `CSVIterator.new(path, {}, 'r:utf-8')` | `CSVIterator.new(path, encoding: 'utf-8')` |
| `CSVIterator.new(path, {}, 'rb')` | `CSVIterator.new(path)` |

Passing a third argument now raises `ArgumentError: wrong number of arguments`.

#### Files are decoded as UTF-8 whatever the locale

In 0.6, files were opened with mode `'rb'` and no encoding, so the result depended on Ruby's default external encoding:

- **UTF-8 locale (the usual case):** csv 3.3+ decoded values as UTF-8. **Nothing changes for you.**
- **Any other locale** (`LANG=C`, which is common in Docker images, cron jobs and some CI runners): values came back as binary (`ASCII-8BIT`) strings. Combining them with UTF-8 strings raised `Encoding::CompatibilityError`.

In 0.7, every class (`CSVIterator`, `CSVCompare`, `CSVSort`, `CSVExtender` and `CSVTransformer`) reads with `encoding: 'bom|utf-8'` unless you pass another encoding. Under a non-UTF-8 locale this changes two things:

- Values are now UTF-8 strings instead of binary strings.
- A file that isn't valid UTF-8 now raises `CSV::InvalidEncodingError` instead of being read as raw bytes.

To keep the 0.6 behavior under such a locale, read raw bytes:

```ruby
CSVUtils::CSVIterator.new(path, encoding: 'BINARY')
CSVUtils::CSVSort.new(path, 'sorted.csv', true, encoding: 'BINARY')
```

For a file that may be Windows-1252, as many Excel exports are, let `CSVOptions` detect the encoding:

```ruby
CSVUtils::CSVIterator.auto_detect(path)
CSVUtils::CSVSort.new(path, 'sorted.csv', true, CSVUtils::CSVOptions.new(path).to_csv_options)
```

#### `CSVExtender`, `CSVTransformer` and `CSVSort` write in the decoded encoding

In 0.6, the same CSV options were used to read the source and to write the output. So `encoding: 'Windows-1252:UTF-8'` decoded the source to UTF-8 and then converted the output back to Windows-1252.

In 0.7, the output is written in the encoding the values were decoded to: UTF-8 for `'Windows-1252:UTF-8'`, `'BOM|UTF-16LE:UTF-8'` and the default `'bom|utf-8'`. An encoding with no conversion, such as `'BINARY'` or `'ISO-8859-1'`, still writes the same bytes it read.

To write a different encoding with `CSVExtender` or `CSVTransformer`, open the destination yourself and pass in the CSV object:

```ruby
CSV.open('output.csv', 'wb', encoding: 'Windows-1252') do |dest|
  CSVUtils::CSVExtender.new('input.csv', dest, encoding: 'Windows-1252:UTF-8').append(['extra']) { |row, _| ['x'] }
end
```

#### `CSVReport` takes its encoding from `encoding:`, not `:mode`

`CSVReport` writes UTF-8 unless you pass an `encoding:`. A `:mode` that carries an encoding now raises `ArgumentError: encoding specified twice`:

| 0.6 | 0.7 |
|---|---|
| `CSVReport.new(path, headers, mode: 'wb:Windows-1252')` | `CSVReport.new(path, headers, encoding: 'Windows-1252')` |
| `CSVReport.new(path, headers, mode: 'ab')` | unchanged |

#### `CSVSort` writes a file without data rows instead of copying it

When the source has no data rows, 0.6 copied it byte for byte. 0.7 writes the header row, if there is one, with the same options as a sorted file. The output is now in the decoded encoding, and it no longer carries the source's byte order mark.

#### `CSVCompare` raises on bad input instead of returning wrong results

- **Out-of-order files:** a file that isn't sorted the way the compare block expects now raises `CSVUtils::UnsortedFileError`, which names the file and the line of the first record out of order. 0.6 yielded bogus creates and deletes instead. The check compares each record with the one before it in the same file, so it only runs for a file whose first record the block compares equal to itself. A block written for different headers in each file skips it. Turn it off with `compare(file, check_order: false)`.
- **Missing update columns:** an update comparison column missing from either file now raises `CSVUtils::HeaderNotFoundError`. 0.6 compared `nil` with `nil` and never reported an update.

#### `CSVOptions` picks the column separator by count

0.6 used the first separator found in the header line, in the order `\x02`, tab, `|`, `,`. 0.7 picks the separator found most often outside quotes in the header row, and a tie goes to the one listed first. `;` is now supported. A header like `cost|usd,name,id` was detected as pipe separated and is now comma separated.

The header row now runs to the first line break outside quotes, so a quoted header with a line break counts its columns correctly. For a file that uses `\r` line breaks, only the header row is read for separators, not the whole first megabyte.

### Other behavior changes

- **`CSVIterator` opens a file on each call, not in `new`.** A missing file now raises `Errno::ENOENT` on the first `each`, `headers`, `size` or `to_hash`, not in `CSVIterator.new`. Every call closes the file when it returns, even when the block raises or stops early.
- **`CSVIterator#each(headers)` strips the byte order mark** from the first value of the first row. In 0.6 that value kept it, for example `"﻿id"`.
- **`CSVOptions#to_csv_options` always includes `encoding:`**, such as `'bom|utf-8'`, `'Windows-1252:UTF-8'` or `'BOM|UTF-16LE:UTF-8'`. Options built from it decode the file to UTF-8 when passed to any class or to `CSV.open(path, 'rb', **options)`.
- **`CSVOptions#encoding` can also be `'Windows-1252'` or `'ISO-8859-1'`.** For files without a byte order mark, these are detected from the first megabyte (`CSVOptions::SAMPLE_SIZE`). In 0.6, `encoding` was always `'UTF-8'` for such files.
- **`RowWrapper#lineno` is the line the row starts on.** It differs from 0.6 only after a quoted value with a line break. 0.6 counted rows, so every later row's `lineno` was too small.
- **`CSVIterator#prev_row` is the header row while the first data row is yielded.** In 0.6 it was `nil` there.
- **Rows CSV can't parse raise `CSVUtils::MalformedRowError`** from `CSVIterator` and `CSVCompare`. It subclasses `CSV::MalformedCSVError`, so existing rescues still match. Its message and `line_number` give the line the bad row starts on, where CSV gives the number of rows read. `prev_row` is the last good row.
- **`CSVIterator#to_hash` raises `CSVUtils::HeaderNotFoundError`**, a `RuntimeError`, as before. The message for an unknown value header now reads `header ... not found` instead of `headers ... not found`.
- **Every error the gem raises includes `CSVUtils::Error`.**
- **`CSVCompare` yields `CSVIterator::RowWrapper` records.** They're still hashes, and now also have `lineno`.
- **`CSVSort` merges up to 64 temporary files at a time,** where 0.6 merged them in pairs. Temporary files are named `<output>.N.tmp` instead of `.part.N` and `.merge.N`, and go in `tmp_dir:` when you pass one.
- **CLI tools detect separators and encodings.** `csv-find-error`, `csv-grep`, `csv-diff`, `csv-splitter` and `csv-explorer` use `CSVOptions`.
  - `csv-find-error` prints `CSVUtils::MalformedRowError` and the physical line.
  - `csv-splitter` writes UTF-8 parts in a single pass.
  - `csv-diff` exits with an error when the two files use different column separators.
