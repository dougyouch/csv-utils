# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'csv-utils'
  s.version     = '0.3.24'
  s.licenses    = ['MIT']
  s.summary     = 'CSV Utils'
  s.description = 'Tools for debugging malformed CSV files'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/csv-utils'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir      = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.add_runtime_dependency 'csv'
  s.add_runtime_dependency 'inheritance-helper'
end
