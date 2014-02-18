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
  attr_reader :run
  attr_accessor :dry_run

  def initialize(dry_run = true)
    @dry_run = dry_run
  end

  def run(command)
    run_type = @dry_run ? 'puts' : 'system'
    method(run_type).call command
  end
end

Command = CommandWrapper.new

# A package, as defined in the YAML spec.
class Package
  def initialize(spec)
    @spec = spec
  end

  def needs_preconfiguration?
    @spec['preconfigure'].class == Array
  end

  def preconfiguration_steps
    @spec['preconfigure'] || []
  end

  def preconfigure(package)
    @preconfiguration_steps.each do |step|
      Command.run "#{step}"
    end
  end

  def configurable?
    @spec['configure'] != false
  end

  def configure_flags
    @spec['configure'].class == Array ? @spec['configure'] : []
  end

  def buildable?
    @spec['build'] || true
  end

  def installable?
    @spec['install'] || true
  end

  def installation_method
    @spec['alternate_install'] || 'make install'
  end

  def remote
    @spec['remote']
  end

  def local_directory
    Config['base_path'] + @spec['local']
  end

  def version
    @spec['version']
  end

  def checkout_version(tag)
    change_to(@local_directory)
    Command.run "git checkout #{tag}"
  end
end



def create_directory(directory)
  Command.run "mkdir --parents #{directory}"
end

def change_to(directory)
  if Command.dry_run
    puts "cd #{directory}"
  else
    Dir.chdir directory if directory_exists? directory
  end
end

def directory_exists?(directory)
  File.directory? directory
end

def create_directory(directory)
  if Command.dry_run
    puts "mkdir --parents"
  Dir.mkdir()

def sync_with_upstream(package)
  directory = "#{Config['base_path']}/#{package.local_directory}"

  create_directory package.local_directory unless directory_exists? package.local_directory
  change_to package.local_directory
  if directory_exists? '.git'
    Command.run 'git pull'
  else
    Command.run "git clone #{package.remote} ."
  end
end

def get_flags(configure_data)
  configure_data.class == Array ? configure_data : []
end

def configure(package)
  configure = './configure ' + package.configure_flags.join(' ')
  configure.gsub!('#{base_path}', "#{Config['base_path']}")
  Command.run "#{configure}"
end


def install(package, with_sudo = false)
  if package.installable?
    installation = package.installation_method
    installation.prepend 'sudo ' if with_sudo
    Command.run "#{installation}"
  end
end

def build(package, building_clean = true)
  Command.run 'make clean' if building_clean
  preconfigure package if package.needs_preconfiguration?
  configure package if package.configurable?
  Command.run 'make'
end

def get_version(package)
  puts package['version']
end

def list_all(packages)
  puts packages.keys
end

def display_info(name, package_data)
  puts name, '---'
  package_data.each do |key, value|
    formatted_key = key.ljust 'alternate_install'.length + 3, ' '
    puts "#{formatted_key}#{value}"
  end
  puts "\n"
end

def install_packages(list, build_only = false, with_sudo = false)
  packages = Config['packages'].select { |name, data| list.include? name }

  packages.each do |name, spec|
    package = Package.new spec

    puts "\nFor package #{name}..."

    sync_with_upstream package
    checkout_version package.version

    build package if package.buildable?
    install package, with_sudo unless build_only == true
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
  c.option '--build-only', 'Builds, but does not install package.'
  c.option '--for-real', 'Actually installs. Default is dry-run.'
  c.option '--install-with-sudo', 'Does what it says on the tin.'
  c.action do |args, options|
    options.default \
      build_only: false, for_real: false, install_with_sudo: false
    Command.dry_run = false if options.for_real
    install_packages args, options.build_only, options.install_with_sudo
  end
end

command :info do |c|
  c.syntax = 'gpm info [options]'
  c.summary = 'Displays known data for package name.'
  c.option '--some-switch', 'Some switch that does something'
  c.action do |args, options|
    args.each do |package_name|
      display_info package_name, Config['packages'][package_name]
    end
  end
end
