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

  def preconfigure
    preconfiguration_steps.each do |step|
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
    "#{Config['base_path']}/#{@spec['local']}"
  end

  def version
    @spec['version']
  end

  def checkout(tag)
    change_to(local_directory)
    Command.run "git checkout #{tag}"
  end

  def sync_with_upstream
    create_directory local_directory
    change_to local_directory
    if directory_exists? "#{local_directory}/.git"
      Command.run 'git pull'
    else
      Command.run "git clone #{remote} ."
    end
  end

  def configure
    configuration = './configure ' + configure_flags.join(' ')
    configuration.gsub!('#{base_path}', "#{Config['base_path']}")
    Command.run "#{configuration}"
  end

  def build(building_clean = true)
    Command.run 'make clean' if building_clean
    preconfigure if needs_preconfiguration?
    configure if configurable?
    Command.run 'make'
  end

  def install(with_sudo = false)
    installation = installation_method
    installation.prepend 'sudo ' if with_sudo
    Command.run "#{installation}"
  end
end

def directory_exists?(directory)
  File.directory? directory
end

def change_to(directory)
  if Command.dry_run
    puts "cd #{directory}"
  else
    Dir.chdir directory if directory_exists? directory
  end
end

def create_directory(directory)
  if Command.dry_run
    puts "mkdir --parents #{directory}"
  else
    Dir.mkdir directory unless directory_exists? directory
  end
end

def display_info(name, spec)
  puts name, '---'
  spec.each do |key, value|
    formatted_key = key.ljust 20, ' '
    puts "#{formatted_key}#{value}"
  end
  puts "\n"
end

def install_packages(list, build_only = false, with_sudo = false)
  packages = Config['packages'].select { |name, data| list.include? name }

  packages.each do |name, spec|
    package = Package.new spec

    package.sync_with_upstream
    package.checkout package.version
    package.build if package.buildable?
    package.install with_sudo if package.installable? && build_only == false
  end
end

command :list do |c|
  c.syntax = 'gpm list [options]'
  c.summary = 'Lists available packages'
  c.action do |args, options|
    puts Config['packages'].keys
  end
end

command :info do |c|
  c.syntax = 'gpm info [options]'
  c.summary = 'Displays known data for package name.'
  c.action do |args, options|
    args.each do |package_name|
      display_info package_name, Config['packages'][package_name]
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
