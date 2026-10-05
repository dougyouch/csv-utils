# Changelog

## [0.6.0](https://github.com/dougyouch/csv-utils/compare/v0.5.0...v0.6.0) (2026-10-05)


### ⚠ BREAKING CHANGES

* **gem:** Ruby 3.2 reached end of life in March 2026 and is no longer supported. The gemspec now declares required_ruby_version >= 3.3.

### Features

* **compare:** accept csv options for both files ([4336edf](https://github.com/dougyouch/csv-utils/commit/4336edf8ca928ebc73c7b58a533ee7280267907e))


### Bug Fixes

* **bom:** detect utf-32 le and strip marks from text in any encoding ([7c68517](https://github.com/dougyouch/csv-utils/commit/7c6851755b9ddfb6ca49b459d9ada578c35a634d))
* **cli:** keep trailing whitespace and raw bytes in csv-change-eol ([a61e53a](https://github.com/dougyouch/csv-utils/commit/a61e53a3add068ebc49c1f6025f06185e8b8a702))
* **cli:** match csv-diff rows on the --unique headers and allow empty cells ([3e0d1ae](https://github.com/dougyouch/csv-utils/commit/3e0d1ae3763090ade46068e056ee909711a2d4df))
* **cli:** read raw bytes in csv-validator ([80c5002](https://github.com/dougyouch/csv-utils/commit/80c5002eb91474d58d7999f41385743c4f719c78))
* **cli:** report line numbers and handle any bytes in csv-duplicate-finder ([f87144d](https://github.com/dougyouch/csv-utils/commit/f87144d07727c9a418c0a37a6e82ceedf55ecf59))
* **cli:** run the bundled csv-readline from csv-find-error ([e6736c6](https://github.com/dougyouch/csv-utils/commit/e6736c6b2682b7611079a1bb5d10ea5df85f3f92))
* **cli:** split single column files with csv-splitter ([ee00da6](https://github.com/dougyouch/csv-utils/commit/ee00da6f9128a744345583541850348490cabdfc))
* **compare:** yield the last record when the other file ends first ([947d2b7](https://github.com/dougyouch/csv-utils/commit/947d2b73d4aa404c52b147782f5bc3c02f5afd42))
* **io:** close files when a block raises ([5ffa159](https://github.com/dougyouch/csv-utils/commit/5ffa159255e6a134721075536f7b70de9f7c1244))
* **iterator:** return an enumerator from each without a block ([751d034](https://github.com/dougyouch/csv-utils/commit/751d034d325279f4eaeca76b726e4a63a6443042))
* **options:** count quoted headers correctly and handle empty files ([abbd084](https://github.com/dougyouch/csv-utils/commit/abbd084a4a2cf84bf27410d616c63e3679f07a14))
* **row:** stop csv_column from changing the options hash passed in ([6a9f916](https://github.com/dougyouch/csv-utils/commit/6a9f916d1e3c9b0f27410a4cae795f80e5968cec))
* **sort:** sort without a block and clean up temporary files on failure ([bc2d21a](https://github.com/dougyouch/csv-utils/commit/bc2d21ae63973323d12084de2710d07e06e70dbb))
* **transformer:** allow append when headers were not read ([9d1e042](https://github.com/dougyouch/csv-utils/commit/9d1e04259e5819eaf5865895674b8aafc8d51c8f))


### Build System

* **gem:** require ruby 3.3 and add gem metadata ([e34a89a](https://github.com/dougyouch/csv-utils/commit/e34a89a473159fa4c70f5279d63ca95499a43c90))

## Changelog
