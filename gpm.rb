#!/usr/bin/env ruby

require 'yaml'

config = YAML.load_file 'gpm.yaml'

# Simple wrapper that either runs or prints a command.
class CommandWrapper
  attr_reader :run

  def initialize(dry_run)
    @execution = dry_run ? 'puts' : 'system'
  end

  def run(command)
    method(@execution).call command
  end
end

Command = CommandWrapper.new config['dry_run']

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

def configure(package, config)
  configure = './configure ' + get_flags(package['configure']).join(' ')
  configure.gsub!('#{base_path}', "#{config['base_path']}")
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
  configure package, config if package['configure']
  Command.run 'make clean' if clean
  Command.run 'make'
end

def traditional_install
  Command.run 'make install'
end

def alternate_install(package)
  Command.run package['alternate_install']
end

config['packages'].each do |name, package|
  puts "\nFor package #{name}..."
  package_path = "#{config['base_path']}/#{package['local']}"

  sync_with_upstream package_path, package['remote']
  checkout_version package['version']

  build package unless package['build'] == false
  unless package['install'] == false || config['build_only'] == false
    install package
  end
end
