# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'open3'
require 'tmpdir'

# Runs a bin/ script in a temporary directory with this checkout's lib on the load path.
module BinHelper
  ROOT = File.expand_path('../..', __dir__)

  def self.included(base)
    base.let(:tmp_dir) { Dir.mktmpdir }
    base.after { FileUtils.remove_entry(tmp_dir) }
  end

  def run_script(script, *, load_path: [])
    includes = [File.join(ROOT, 'lib'), *load_path].flat_map { |dir| ['-I', dir] }
    Open3.capture3(RbConfig.ruby, *includes, File.join(ROOT, 'bin', script), *, chdir: tmp_dir)
  end

  def write_file(name, content)
    path = File.join(tmp_dir, name)
    File.binwrite(path, content)
    path
  end

  def tmp_path(name)
    File.join(tmp_dir, name)
  end
end
