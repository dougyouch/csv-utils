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

### Other behavior changes

- **`CSVIterator` opens a file on each call, not in `new`.** A missing file now raises `Errno::ENOENT` on the first `each`, `headers`, `size` or `to_hash`, not in `CSVIterator.new`. Every call closes the file when it returns, even when the block raises or stops early.
- **`CSVIterator#each(headers)` strips the byte order mark** from the first value of the first row. In 0.6 that value kept it, for example `"﻿id"`.
- **`CSVOptions#to_csv_options` always includes `encoding:`**, such as `'bom|utf-8'`, `'Windows-1252:UTF-8'` or `'BOM|UTF-16LE:UTF-8'`. Options built from it decode the file to UTF-8 when passed to any class or to `CSV.open(path, 'rb', **options)`.
- **`CSVOptions#encoding` can also be `'Windows-1252'` or `'ISO-8859-1'`.** For files without a byte order mark, these are detected from the first megabyte (`CSVOptions::SAMPLE_SIZE`). In 0.6, `encoding` was always `'UTF-8'` for such files.
