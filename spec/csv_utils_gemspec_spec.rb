# frozen_string_literal: true

require 'spec_helper'

describe 'csv-utils.gemspec' do
  let(:spec) { Gem::Specification.load(File.expand_path('../csv-utils.gemspec', __dir__)) }

  it 'packages only the library, executables and user-facing docs' do
    expect(spec.files.reject { |file| file.start_with?('lib/', 'bin/') }).to contain_exactly(
      'CHANGELOG.md', 'LICENSE', 'README.md'
    )
  end

  it 'installs every command line tool' do
    expect(spec.executables).to match_array(Dir[File.expand_path('../bin/*', __dir__)].map { |f| File.basename(f) })
  end

  it 'limits inheritance-helper to compatible versions' do
    dependency = spec.runtime_dependencies.find { |dep| dep.name == 'inheritance-helper' }
    expect(dependency.requirement).to be_satisfied_by(Gem::Version.new('0.2.6'))
    expect(dependency.requirement).to be_satisfied_by(Gem::Version.new('1.9.0'))
    expect(dependency.requirement).not_to be_satisfied_by(Gem::Version.new('2.0.0'))
  end

  it 'links to the source, changelog, issues and api docs' do
    expect(spec.metadata).to include(
      'source_code_uri' => 'https://github.com/dougyouch/csv-utils',
      'changelog_uri' => 'https://github.com/dougyouch/csv-utils/blob/master/CHANGELOG.md',
      'bug_tracker_uri' => 'https://github.com/dougyouch/csv-utils/issues',
      'documentation_uri' => 'https://rubydoc.info/gems/csv-utils'
    )
  end
end
