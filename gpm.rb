#!/usr/bin/env ruby

require 'yaml'
require 'rubygems'
require 'commander/import'
require 'fileutils'

program :name, 'gpm'
program :version, '1.0.1'
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
  def initialize(name, spec)
    @name, @spec = name, spec
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
    change_to local_directory
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

  def deploy(with_sudo = false, elsewhere)
    installation = installation_method
    installation.prepend 'sudo ' if with_sudo
    installation.concat " DESTDIR=#{elsewhere}" if elsewhere
    Command.run "#{installation}"
  end

  def build_rpm
    build_path = "/data/tmp/build/#{@spec['local']}"
    deploy build_path
    content = Dir.entries(build_path).join(' ') if directory_exists? build_path
    Command.run "fpm -s dir -t rpm -n #{@name} -v #{version} \
      -C #{build_path} -p /data/rpm/#{@name}-#{version}.rpm #{content}"
  end

  def install(build_only = false, with_sudo = false, building_rpm = false)
    sync_with_upstream
    checkout version
    build if buildable?
    if installable?
      build_rpm if building_rpm
      deploy with_sudo unless build_only
    end
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
    FileUtils.mkpath directory
  end
end

def longest_key(hash)
  longest_known = 0
  hash.keys.each do |key|
    longest_known = key.length if key.length > longest_known
  end
  longest_known
end

def display_info(name, spec)
  puts name, '---'
  spec.each do |key, value|
    formatted_key = key.ljust longest_key(spec) + 3, ' '
    puts "#{formatted_key}#{value}"
  end
  puts "\n"
end

def install_packages(list, build_only = false, sudo = false, rpm = false)
  packages = Config['packages'].select { |name, data| list.include? name }

  packages.each do |name, spec|
    package = Package.new name, spec
    package.install build_only, sudo, rpm
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
  c.option '--with-sudo', 'Installs with sudo.'
  c.option '--rpm', 'Builds an RPM'
  c.action do |args, options|
    options.default \
      build_only: false, for_real: false, with_sudo: false, rpm: false
    Command.dry_run = false if options.for_real
    install_packages args, options.build_only, options.with_sudo, options.rpm
  end
end
