# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'json'
require 'securerandom'
require 'simplecov'

SimpleCov.start do
  enable_coverage :branch

  add_filter '/spec/'

  add_group 'Core', 'lib/csv_utils'
  add_group 'CLI', 'bin'

  track_files 'lib/**/*.rb'
end

begin
  Bundler.require(:default, :development, :spec)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

$LOAD_PATH.unshift(File.join(__FILE__, '../..', 'lib'))
$LOAD_PATH.unshift(File.expand_path(__dir__))
require 'csv-utils'
