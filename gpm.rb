#!/usr/bin/env ruby

require 'yaml'
require 'rubygems'
require 'commander/import'

program :name, 'gpm'
program :version, '0.0.1'
program :description, 'Ghetto Package Management'

Config = YAML.load_file 'gpm.yaml'

# Simple wrapper that either runs or prints a command.
class CommandWrapper
  attr_reader :run, :change

  def initialize(dry_run)
    @execution = dry_run ? 'puts' : 'system'
  end

  def change(execution)
    @execution = execution
  end

  def run(command)
    method(@execution).call command
  end
end

Command = CommandWrapper.new Config['dry_run']

def create_directory(directory)
  Command.run "mkdir --parents #{directory}"
end

def change_to(directory)
  Command.run "cd #{directory}"
end

def directory_exists?(directory)
  File.directory? directory
end

def sync_with_upstream(directory, repository)
  create_directory directory unless directory_exists? directory
  change_to directory
  if directory_exists? '.git'
    Command.run 'git pull'
  else
    Command.run "git clone #{repository} ."
  end
end

def checkout_version(tag)
  Command.run "git checkout #{tag}"
end

def get_flags(configure_data)
  if configure_data.class == Hash
    configure_data['flags'] || []
  else
    []
  end
end

def configure(package)
  configure = './configure ' + get_flags(package['configure']).join(' ')
  configure.gsub!('#{base_path}', "#{Config['base_path']}")
  Command.run "#{configure}"
end

def run_autoconf
  Command.run 'autoconf'
end

def install(package)
  if package['alternate_install']
    alternate_install package
  else
    traditional_install
  end
end

def build(package, clean = false)
  run_autoconf if package['needs_autoconf']
  configure package if package['configure']
  Command.run 'make clean' if clean
  Command.run 'make'
end

def traditional_install
  Command.run 'make install'
end

def alternate_install(package)
  Command.run package['alternate_install']
end

def get_version(package)
  puts package['version']
end

def list_all(packages)
  puts packages.keys
end

def display_info(name, data)
  puts "\n", name, '-'.ljust(name.length, '-')
  data.each do |key, value|
    formatted_key = key.ljust 'configure'.length + 3, ' '
    puts "#{formatted_key}#{value}"
  end
  puts "\n"
end

def install_packages(package_list, build_only = false)
  packages = {}

  package_list.each do |package_name|
    packages[package_name] = Config['packages'][package_name]
  end

  packages.each do |name, package|
    puts "\nFor package #{name}..."
    package_path = "#{Config['base_path']}/#{package['local']}"

    sync_with_upstream package_path, package['remote']
    checkout_version package['version']

    build package unless package['build'] == false
    unless package['install'] == false || build_only == false
      install package
    end
  end
end

command :list do |c|
  c.syntax = 'gpm list [options]'
  c.summary = 'Lists available packages'
  c.action do |args, options|
    list_all Config['packages']
  end
end

command :version do |c|
  c.syntax = 'gpm version <package>'
  c.summary = 'Displays the selected version of a given package.'
  c.action do |args, options|
    args.each do |package_name|
      get_version Config['packages'][package_name]
    end
  end
end

command :install do |c|
  c.syntax = 'gpm install [options] <package>'
  c.summary = 'Installs a specific package.'
  c.example 'description', 'command example'
  c.option '--build-only', 'Builds, but does not install package.'
  c.option '--for-real', 'Actually installs. Default is dry-run.'
  c.option '--release STRING', String, 'Install a specific release (as referenced by git tag).'
  c.action do |args, options|
    options.default :build_only => Config['build_only'], :for_real => false
    Command.change('echo') if options.for_real
    install_packages args, options.build_only
  end
end

command :info do |c|
  c.syntax = 'gpm info [options]'
  c.summary = 'Displays known data for package name.'
  c.example 'description', 'command example'
  c.option '--some-switch', 'Some switch that does something'
  c.action do |args, options|
    args.each do |package_name|
      display_info package_name, Config['packages'][package_name]
    end
  end
end
