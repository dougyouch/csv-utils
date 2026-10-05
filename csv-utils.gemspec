# frozen_string_literal: true

require_relative 'lib/csv_utils/version'

Gem::Specification.new do |s|
  s.name        = 'csv-utils'
  s.version     = CSVUtils::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Compare, sort, transform and debug large or malformed CSV files'
  s.description = 'Streaming tools for CSV files too big or too broken to load into memory. Compare two sorted ' \
                  'files into create, update and delete actions, sort with an external merge sort, transform ' \
                  'and extend rows in batches, and build reports from Ruby objects. Detects separators, byte ' \
                  'order marks and encodings, and ships command line tools that pinpoint malformed rows, diff, ' \
                  'grep, split and validate CSV files.'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/csv-utils'
  s.files       = Dir['lib/**/*.rb', 'bin/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  s.required_ruby_version = '>= 3.3'
  s.bindir      = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.add_dependency 'csv', '>= 3.0'
  s.add_dependency 'inheritance-helper', '>= 0.2', '< 2'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri'] = 'https://github.com/dougyouch/csv-utils'
  s.metadata['changelog_uri'] = 'https://github.com/dougyouch/csv-utils/blob/master/CHANGELOG.md'
  s.metadata['bug_tracker_uri'] = 'https://github.com/dougyouch/csv-utils/issues'
  s.metadata['documentation_uri'] = 'https://rubydoc.info/gems/csv-utils'
end
